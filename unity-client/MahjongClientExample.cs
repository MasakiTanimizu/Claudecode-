// MahjongClientExample: minimal usage sample for MahjongWebSocketClient
// (docs/UNITY_INTEGRATION.md). Connects, joins, and on every state
// update where it's this player's turn to discard, discards the first
// tile in hand — enough to see a full hand play out end-to-end against
// the two CPU seats without wiring up any real UI yet.
//
// NOTE: not compiled or run — there is no Unity Editor in the
// environment this was written in. Attach this to any GameObject in an
// empty scene to try it once a Unity project exists.

using UnityEngine;

namespace Mahjong.Net
{
    public class MahjongClientExample : MonoBehaviour
    {
        [SerializeField] private string serverUrl = "ws://localhost:8080";
        [SerializeField] private string playerName = "Player";

        private MahjongWebSocketClient _client;

        private async void Start()
        {
            _client = new MahjongWebSocketClient();
            _client.OnState += HandleState;
            _client.OnCallOpportunity += HandleCallOpportunity;
            _client.OnHandResult += HandleHandResult;
            _client.OnServerError += msg => Debug.LogWarning($"Server error: {msg}");
            _client.OnTransportError += ex => Debug.LogError($"Transport error: {ex}");

            try
            {
                await _client.ConnectAsync(serverUrl);
                await _client.Join(playerName);
            }
            catch (System.Exception ex)
            {
                Debug.LogError($"Failed to connect to {serverUrl}: {ex}");
            }
        }

        private void Update()
        {
            _client?.Pump();
        }

        private async void OnDestroy()
        {
            if (_client != null) await _client.DisconnectAsync();
        }

        private async void HandleState(GameStateView state)
        {
            PlayerView self = null;
            foreach (var p in state.players)
            {
                if (p.seat == state.yourSeat) self = p;
            }
            if (self == null) return;

            Debug.Log($"[state] seat={state.yourSeat} turn={state.round.turn} handSize={self.hand?.Length ?? 0} score={self.score}");

            // 14 tiles held on your own seat's turn means you've just
            // drawn and are expected to act (kita/hana/riichi/discard/
            // tsumo). This demo always just discards its first tile.
            bool isMyTurn = state.round.turn == state.yourSeat;
            bool holdingDrawnTile = self.hand != null && self.hand.Length == 14;
            if (isMyTurn && holdingDrawnTile)
            {
                await _client.Discard(self.hand[0].id);
            }
        }

        private async void HandleCallOpportunity(CallOpportunityMessage call)
        {
            Debug.Log($"[callOpportunity] {call.discardedTile.suit}{call.discardedTile.rank} from seat {call.fromSeat}");
            // Conservative default for this demo: always pass on ron.
            await _client.Pass();
        }

        private void HandleHandResult(HandResultMessage result)
        {
            if (result.isDraw)
            {
                Debug.Log("[handResult] exhaustive draw");
                return;
            }
            if (result.isTsumo)
            {
                Debug.Log($"[handResult] seat {result.winner} won by tsumo");
            }
            else
            {
                Debug.Log($"[handResult] seat(s) [{string.Join(",", result.winners)}] won by ron off seat {result.discarderSeat}");
            }
        }
    }
}
