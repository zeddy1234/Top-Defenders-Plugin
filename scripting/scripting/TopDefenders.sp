#pragma newdecls required
#pragma semicolon 1

#include <zombiereloaded>
#include <csgocolors_fix>
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <UIManager>
#include <TopDefenders>

enum struct PlayerData
{
	int hDamage;
	int hHits;
	int hRank;

	int zInfects;
	int zDamage;

	void Reset()
	{
		this.hDamage = 0;
		this.hHits = 0;
		this.hRank = -1;
		this.zInfects = 0;
		this.zDamage = 0;
	}
}

PlayerData g_playerData[MAXPLAYERS+1];

int g_iTopDefenders[5];
int g_iTopInfectors[5];
int g_iHumanRank[MAXPLAYERS+1];

int g_iSortedList[MAXPLAYERS+1][3]; // [rank][damage][hits]
int g_iSortedZombieList[MAXPLAYERS+1][3]; // [rank][damage taken][infects]
int g_iSortedCount = 0;
int g_iSortedZombieCount = 0;

Handle g_hTimer;

ConVar g_cvMinDamage, g_cvMinVictim; // Minimum damage dealt/received
ConVar g_cvUpdate; // Update rate

public Plugin myinfo =
{
	name        = "Top Defenders",
	author      = "koen, ZeddY^",
	description = "",
	version     = "",
	url         = "https://github.com/notkoen"
};

public void OnPluginStart()
{
	// Load translations
	LoadTranslations("TopDefenders.phrases");
	LoadTranslations("common.phrases");

	// ConVars
	g_cvMinDamage = CreateConVar("sm_topdefender_dmgmin", "5000", "Minimum human damage to be displayed", _, true, 0.0);
	g_cvMinVictim = CreateConVar("sm_topdefender_mindmgreceived", "10000", "Minimum zombie damage received to be displayed", _, true, 0.0);
	g_cvUpdate = CreateConVar("sm_topdefender_rate", "10.0", "Top defenders list update rate", _, true, 0.1);
	HookConVarChange(g_cvUpdate, OnTimerUpdate);

	AutoExecConfig(true, "TopDefenders");

	// Command
	RegConsoleCmd("sm_tdrank", Cmd_TDRank, "Check your current top defender rank.");
	RegConsoleCmd("sm_tdfind", Cmd_TDFind, "Find the defender stats given rank or name");

	// Event Hooks
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_hurt", Event_PlayerHurt);
}

public void OnMapStart()
{
	g_hTimer = CreateTimer(g_cvUpdate.FloatValue, UpdateDefendersList, _, TIMER_REPEAT);
}

public void OnMapEnd()
{
	if (g_hTimer != INVALID_HANDLE)
		delete g_hTimer;
}

public void OnTimerUpdate(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	delete g_hTimer;
	g_hTimer = CreateTimer(g_cvUpdate.FloatValue, UpdateDefendersList, _, TIMER_REPEAT);
}

//---------------[ Natives ]---------------//
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("TopDefenders");
	CreateNative("TopDefenderStats", Native_TDStats);
	return APLRes_Success;
}

public int Native_TDStats(Handle plugin, int numParams)
{
	StatType type = view_as<StatType>(GetNativeCell(2));

	switch (type)
	{
		case TD_Rank: return g_iHumanRank[GetNativeCell(1)] + 1;
		case TD_Damage: return g_playerData[GetNativeCell(1)].hDamage;
		case TD_Hits: return g_playerData[GetNativeCell(1)].hHits;
		case TD_Infects: return g_playerData[GetNativeCell(1)].zInfects;
		case TD_ReceivedDamage: return g_playerData[GetNativeCell(1)].zDamage;
	}
	return 1;
}

public void OnClientDisconnect(int client)
{
	g_playerData[client].Reset();
}

//---------------[ Command Callbacks ]---------------//
public Action Cmd_TDRank(int client, int args)
{
	for (int i = 0; i < sizeof(g_iSortedList); i++)
	{
		if (g_iSortedList[i][0] == client)
		{
			CReplyToCommand(client, "%t %t", "Prefix", "TDRank", i + 1, client, g_iSortedList[i][1], g_iSortedList[i][2]);
			break;
		}
	}

	return Plugin_Handled;
}

public Action Cmd_TDFind(int client, int args)
{
	if (args < 1)
	{
		for (int i = 0; i < sizeof(g_iSortedList); i++)
		{
			if (g_iSortedList[i][0] == client)
			{
				CReplyToCommand(client, "%t %t", "Prefix", "TDRank", i + 1, client, g_iSortedList[i][1], g_iSortedList[i][2]);
				break;
			}
		}
		return Plugin_Handled;
	}

	char buffer[32];
	GetCmdArg(1, buffer, sizeof(buffer));

	int index = StringToInt(buffer);
	if (index == 0 || index > MaxClients)
	{
		int target = FindTarget(client, buffer, false, false);
		if (target == -1)
			return Plugin_Handled;

		for (int i = 0; i < sizeof(g_iSortedList); i++)
		{
			if (g_iSortedList[i][0] == target)
			{
				CReplyToCommand(client, "%t %t", "Prefix", "TDRank", i + 1, target, g_iSortedList[i][1], g_iSortedList[i][2]);
				break;
			}
		}
		return Plugin_Handled;
	}
	else
	{
		if (!IsClientInGame(index))
		{
			CPrintToChat(client, "%t %t", "Prefix", "Client Not Found", index);
			return Plugin_Handled;
		}
		CPrintToChat(client, "%t %t", "Prefix", "TDRank", index, g_iSortedList[index-1][0], g_iSortedList[index-1][1], g_iSortedList[index-1][2]);
		return Plugin_Handled;
	}
}

//---------------[ Events ]---------------//
public void Event_RoundStart(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	// Reset all player data
	for (int client = 1; client <= MaxClients; client++)
		g_playerData[client].Reset();
}

public void Event_RoundEnd(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	g_iTopDefenders = {-1, -1, -1, -1, -1};
	g_iTopInfectors = {-1, -1, -1, -1, -1};

	UpdateDefendersList(INVALID_HANDLE);
	UpdateZombiesList();

	if (!g_iSortedCount)
		return;

	char buffer[2048];
	Format(buffer, sizeof(buffer), "%t", "Hud Header");

	for (int i = 0; i < sizeof(g_iTopDefenders); i++)
	{
		if (g_iSortedList[i][0] > 0 && g_iSortedList[i][1] > g_cvMinDamage.IntValue)
		{
			AddClientMVP(g_iSortedList[i][0], sizeof(g_iTopDefenders) - i);
			Format(buffer, sizeof(buffer), "%s\n%t", buffer, "Hud Rank Text", i + 1, g_iSortedList[i][0], g_iSortedList[i][1], g_iSortedList[i][2]);
			g_iTopDefenders[i] = GetSteamAccountID(g_iSortedList[i][0]);
		}
		else
		{
			if (i == 0)
			{
				int msg = GetRandomInt(1, 4);
				switch (msg)
				{
					case 1:
						Format(buffer, sizeof(buffer), "%s\n%t", buffer, "No Defenders 1");
					case 2:
						Format(buffer, sizeof(buffer), "%s\n%t", buffer, "No Defenders 2");
					case 3:
						Format(buffer, sizeof(buffer), "%s\n%t", buffer, "No Defenders 3");
					case 4:
						Format(buffer, sizeof(buffer), "%s\n%t", buffer, "No Defenders 4");
				}
			}
			break;
		}
	}

	Format(buffer, sizeof(buffer), "%s\n\n%t", buffer, "Zombie Stats Header");

	for (int i = 0; i < sizeof(g_iTopInfectors); i++)
	{
		if (g_iSortedZombieList[i][0] > 0 && g_iSortedZombieList[i][1] > g_cvMinVictim.IntValue)
		{
			Format(buffer, sizeof(buffer), "%s\n%t", buffer, "Zombie Rank Hud", i + 1, g_iSortedZombieList[i][0], g_iSortedZombieList[i][1], g_iSortedZombieList[i][2]);
			g_iTopInfectors[i] = GetSteamAccountID(g_iSortedZombieList[i][0]);
		}
		else
		{
			if (i == 0)
			{
				int msg2 = GetRandomInt(1, 4);
				switch (msg2)
				{
					case 1:
						Format(buffer, sizeof(buffer), "%s\n%t", buffer, "Shit Zombies 1");
					case 2:
						Format(buffer, sizeof(buffer), "%s\n%t", buffer, "Shit Zombies 2");
					case 3:
						Format(buffer, sizeof(buffer), "%s\n%t", buffer, "Shit Zombies 3");
					case 4:
						Format(buffer, sizeof(buffer), "%s\n%t", buffer, "Shit Zombies 4");
				}
			}
			break;
		}
	}

	// Prevent top defender display from conflicting with round overlay
	DataPack pack;
	CreateDataTimer(0.1, SendHud, pack);
	pack.WriteString(buffer);
}

public Action SendHud(Handle timer, DataPack pack)
{
	char buffer[2048];
	pack.Reset();
	pack.ReadString(buffer, sizeof(buffer));
	SendHtmlHudToAll(10.0, true, buffer);
	return Plugin_Stop;
}

public void Event_PlayerHurt(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	if (!(1 <= attacker <= MaxClients) || !IsClientInGame(attacker))
		return;

	if (GetClientTeam(attacker) != CS_TEAM_CT)
		return;

	int victim = GetClientOfUserId(hEvent.GetInt("userid"));

	if (!(1 <= victim <= MaxClients) || attacker == victim)
		return;

	int iDamage = hEvent.GetInt("dmg_health");

	g_playerData[attacker].hDamage += iDamage;
	g_playerData[victim].zDamage += iDamage;
	g_playerData[attacker].hHits++;
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	if (attacker != -1)
		g_playerData[attacker].zInfects++;
}

//---------------[ Stock Functions ]---------------//
stock void AddClientMVP(int client, int amount)
{
	CS_SetMVPCount(client, CS_GetMVPCount(client) + amount);
}

public Action UpdateDefendersList(Handle timer)
{
	for (int i = 0; i < sizeof(g_iHumanRank); i++)
		g_iHumanRank[i] = 0;

	for (int i = 0; i < sizeof(g_iSortedList); i++)
	{
		g_iSortedList[i][0] = -1;
		g_iSortedList[i][1] = 0;
		g_iSortedList[i][2] = 0;
	}

	g_iSortedCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;

		g_iSortedList[g_iSortedCount][0] = client;
		g_iSortedList[g_iSortedCount][1] = g_playerData[client].hDamage;
		g_iSortedList[g_iSortedCount][2] = g_playerData[client].hHits;
		g_iSortedCount++;
	}

	SortCustom2D(g_iSortedList, g_iSortedCount, Sort2DArray);

	for (int i = 0; i < g_iSortedCount; i++)
		g_iHumanRank[g_iSortedList[i][0]] = i;

	if (timer == INVALID_HANDLE)
		return Plugin_Stop;
	else
		return Plugin_Continue;
}

stock void UpdateZombiesList()
{
	for (int i = 0; i < sizeof(g_iSortedZombieList); i++)
	{
		g_iSortedZombieList[i][0] = -1;
		g_iSortedZombieList[i][1] = 0; // Damage taken
		g_iSortedZombieList[i][2] = 0; // Infections
	}

	g_iSortedZombieCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || g_playerData[client].zDamage == 0)
			continue;

		g_iSortedZombieList[g_iSortedZombieCount][0] = client;
		g_iSortedZombieList[g_iSortedZombieCount][1] = g_playerData[client].zDamage;
		g_iSortedZombieList[g_iSortedZombieCount][2] = g_playerData[client].zInfects;
		g_iSortedZombieCount++;
	}

	SortCustom2D(g_iSortedZombieList, g_iSortedZombieCount, Sort2DArray);
}

public int Sort2DArray(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	if (elem1[1] > elem2[1]) return -1;
	if (elem1[1] < elem2[1]) return 1;
	return 0;
}
