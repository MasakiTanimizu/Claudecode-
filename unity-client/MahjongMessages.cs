// MahjongMessages: plain data classes mirroring the JSON wire format in
// docs/UNITY_INTEGRATION.md, for use with Unity's built-in JsonUtility.
//
// JsonUtility can't deserialize by a discriminator field on its own, so
// MahjongWebSocketClient first parses every frame into TypeOnlyMessage
// to read `type`, then re-parses the same raw string into the matching
// class below (JsonUtility silently ignores JSON fields a class doesn't
// declare, which is what makes that two-pass approach work).
//
// NOTE: this file has not been compiled or run — there is no Unity
// Editor in the environment this was written in. It is written to be
// syntactically correct and to match GameLoop.js's actual emitted
// shapes (see server/GameLoop.js's _buildStateView/_emitHandResult),
// but should be verified against a real Unity project before use.

using System;

namespace Mahjong.Net
{
    [Serializable]
    public class Tile
    {
        public string id;
        public string suit;   // "m" | "p" | "s" | "z" | "f"
        public int rank;
        public string variant; // e.g. "red" | "blue" | "black" | null
    }

    [Serializable]
    public class Meld
    {
        public string type; // "pon" | "kan"
        public string suit;
        public int rank;
        public bool concealed;
        public int calledFrom;
        public Tile[] tiles;
    }

    [Serializable]
    public class RoundView
    {
        public int roundWind;
        public int roundNumber;
        public int honba;
        public int kyoutakuPoints;
        public int dealerSeat;
        public int turn;
        public Tile[] doraIndicators;
    }

    [Serializable]
    public class PlayerView
    {
        public int seat;
        public bool isDealer;
        // Populated only for `seat == yourSeat` (your own hand). For
        // every other seat this is empty/null and handSize is the
        // count to render face-down instead.
        public Tile[] hand;
        public int handSize;
        public Tile[] discards;
        public Meld[] melds;
        public int kitaCount;
        public int flowerCount;
        public bool riichiActive;
        public int score;
        public int chip;
    }

    [Serializable]
    public class GameStateView
    {
        public int yourSeat;
        public RoundView round;
        public PlayerView[] players;
    }

    // ---- envelopes, one per server -> client message type ----

    [Serializable]
    public class TypeOnlyMessage
    {
        public string type;
    }

    [Serializable]
    public class StateMessage
    {
        public string type; // "state"
        public GameStateView state;
    }

    [Serializable]
    public class CallOpportunityMessage
    {
        public string type; // "callOpportunity"
        public Tile discardedTile;
        public int fromSeat;
        public string[] options; // currently always ["ron", "pass"]
    }

    [Serializable]
    public class YakuEntry
    {
        public string name;
        public int han;
    }

    // One winner's settlement detail, nested inside HandResultMessage.results.
    // Some deeply-nested breakdown objects (chipResult/specialBonus/demekin/
    // tobashi/doraResult from TurnEngine.resolveWin) are intentionally left
    // out of this strongly-typed model for now — read the raw JSON directly
    // if the UI needs those numbers before a typed model is added for them.
    [Serializable]
    public class WinResult
    {
        public int seat;
        public int fu;
        public int han;
        public int baseScore; // TurnEngine's `base` (avoiding the C# keyword)
        public bool isYakuman;
        public YakuEntry[] yakuList;
        public int[] scoreDeltas;
    }

    [Serializable]
    public class HandResultMessage
    {
        public string type; // "handResult"

        // Tsumo:
        public int winner;
        public bool isTsumo;

        // Ron / double-ron (winners.Length can be 2 on a double ron):
        public int[] winners;
        public int discarderSeat;

        // Exhaustive draw:
        public bool isDraw;
        public bool[] tenpaiFlags;
        public int[] deltas;

        // Present for both tsumo and ron, one entry per winning seat.
        public WinResult[] results;
    }

    [Serializable]
    public class ErrorMessage
    {
        public string type; // "error"
        public string message;
    }

    // ---- client -> server messages ----

    [Serializable]
    public class JoinMessage
    {
        public string type = "join";
        public string playerName;
    }

    [Serializable]
    public class DiscardMessage
    {
        public string type = "discard";
        public string tileId;
    }

    [Serializable]
    public class RiichiMessage
    {
        public string type = "riichi";
        public bool open;
        public string shubaTier; // "shuba" | "shubazoma" | "shubante" | null
    }

    [Serializable]
    public class KitaMessage
    {
        public string type = "kita";
        public string tileId;
    }

    [Serializable]
    public class HanaMessage
    {
        public string type = "hana";
        public string tileId;
    }

    [Serializable]
    public class SimpleActionMessage
    {
        public string type; // "tsumo" | "ron" | "pass"
    }
}
