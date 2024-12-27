#if defined _TopDefenders_included
    #endinput
#endif
#define _TopDefenders_included

enum StatType
{
    TD_Rank,
    TD_Damage,
    TD_Hits,
    TD_Kills,
    TD_Infects,
    TD_ReceivedDamage,
};

native int TopDefenderStats(int client, StatType type);

public SharedPlugin __pl_TopDefenders = 
{
    name = "TopDefenders",
    file = "TopDefenders.smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_TopDefenders_SetNTVOptional()
{
    MarkNativeAsOptional("TopDefenderStats");
}
#endif