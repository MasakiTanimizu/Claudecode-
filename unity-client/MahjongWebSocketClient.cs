// MahjongWebSocketClient: connects to server/index.js and translates
// its JSON frames (docs/UNITY_INTEGRATION.md) into typed C# events.
//
// This is a plain C# class, not a MonoBehaviour, so it can be owned by
// whatever MonoBehaviour manages the match. Receiving happens on a
// background task; to keep Unity API calls on the main thread, incoming
// frames are queued and only dispatched when the owner calls Pump()
// (call this once per frame, e.g. from Update()).
//
// Uses System.Net.WebSockets.ClientWebSocket, which works for a
// standalone/editor build but NOT for WebGL (WebGL has no real
// sockets). A WebGL build needs the NativeWebSocket package instead and
// a different transport implementation behind the same event surface.
//
// NOTE: not compiled or run — there is no Unity Editor in the
// environment this was written in. Written to be syntactically correct
// C# against the .NET WebSockets API and Unity's JsonUtility, but
// verify against a real Unity project before use.

using System;
using System.Collections.Concurrent;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using UnityEngine;

namespace Mahjong.Net
{
    public class MahjongWebSocketClient
    {
        public event Action<GameStateView> OnState;
        public event Action<CallOpportunityMessage> OnCallOpportunity;
        public event Action<HandResultMessage> OnHandResult;
        public event Action<string> OnServerError;
        public event Action<Exception> OnTransportError;

        private ClientWebSocket _socket;
        private CancellationTokenSource _cts;
        private readonly ConcurrentQueue<string> _incoming = new ConcurrentQueue<string>();

        public bool IsConnected => _socket != null && _socket.State == WebSocketState.Open;

        public async Task ConnectAsync(string url)
        {
            _socket = new ClientWebSocket();
            _cts = new CancellationTokenSource();
            await _socket.ConnectAsync(new Uri(url), _cts.Token);
            _ = ReceiveLoopAsync();
        }

        public async Task DisconnectAsync()
        {
            if (_socket == null) return;
            _cts?.Cancel();
            if (_socket.State == WebSocketState.Open)
            {
                await _socket.CloseAsync(WebSocketCloseStatus.NormalClosure, "client closing", CancellationToken.None);
            }
            _socket.Dispose();
            _socket = null;
        }

        // ---- outgoing actions ----

        public Task Join(string playerName) => SendJson(new JoinMessage { playerName = playerName });

        public Task Discard(string tileId) => SendJson(new DiscardMessage { tileId = tileId });

        public Task Riichi(bool open = false, string shubaTier = null) =>
            SendJson(new RiichiMessage { open = open, shubaTier = shubaTier });

        public Task Kita(string tileId) => SendJson(new KitaMessage { tileId = tileId });

        public Task Hana(string tileId) => SendJson(new HanaMessage { tileId = tileId });

        public Task Tsumo() => SendJson(new SimpleActionMessage { type = "tsumo" });

        public Task Ron() => SendJson(new SimpleActionMessage { type = "ron" });

        public Task Pass() => SendJson(new SimpleActionMessage { type = "pass" });

        private async Task SendJson(object message)
        {
            if (_socket == null || _socket.State != WebSocketState.Open)
            {
                throw new InvalidOperationException("MahjongWebSocketClient is not connected");
            }
            string json = JsonUtility.ToJson(message);
            byte[] bytes = Encoding.UTF8.GetBytes(json);
            await _socket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, _cts.Token);
        }

        // ---- receiving ----

        private async Task ReceiveLoopAsync()
        {
            var buffer = new byte[8192];
            try
            {
                while (_socket.State == WebSocketState.Open)
                {
                    using (var ms = new System.IO.MemoryStream())
                    {
                        WebSocketReceiveResult result;
                        do
                        {
                            result = await _socket.ReceiveAsync(new ArraySegment<byte>(buffer), _cts.Token);
                            if (result.MessageType == WebSocketMessageType.Close)
                            {
                                await _socket.CloseAsync(WebSocketCloseStatus.NormalClosure, "server closed", CancellationToken.None);
                                return;
                            }
                            ms.Write(buffer, 0, result.Count);
                        } while (!result.EndOfMessage);

                        string json = Encoding.UTF8.GetString(ms.ToArray());
                        _incoming.Enqueue(json);
                    }
                }
            }
            catch (OperationCanceledException)
            {
                // expected on DisconnectAsync
            }
            catch (Exception ex)
            {
                _incoming.Enqueue(null);
                OnTransportError?.Invoke(ex);
            }
        }

        // Call once per frame (e.g. from a MonoBehaviour's Update()) to
        // dispatch any frames that arrived since the last call, on the
        // main thread.
        public void Pump()
        {
            while (_incoming.TryDequeue(out string json))
            {
                if (json == null) continue; // transport-error sentinel, already reported
                DispatchFrame(json);
            }
        }

        private void DispatchFrame(string json)
        {
            TypeOnlyMessage envelope;
            try
            {
                envelope = JsonUtility.FromJson<TypeOnlyMessage>(json);
            }
            catch (Exception ex)
            {
                OnTransportError?.Invoke(ex);
                return;
            }

            switch (envelope.type)
            {
                case "state":
                    OnState?.Invoke(JsonUtility.FromJson<StateMessage>(json).state);
                    break;
                case "callOpportunity":
                    OnCallOpportunity?.Invoke(JsonUtility.FromJson<CallOpportunityMessage>(json));
                    break;
                case "handResult":
                    OnHandResult?.Invoke(JsonUtility.FromJson<HandResultMessage>(json));
                    break;
                case "error":
                    OnServerError?.Invoke(JsonUtility.FromJson<ErrorMessage>(json).message);
                    break;
                default:
                    Debug.LogWarning($"MahjongWebSocketClient: unknown message type '{envelope.type}'");
                    break;
            }
        }
    }
}
