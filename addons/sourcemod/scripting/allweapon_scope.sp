#pragma semicolon 1

#define DEBUG 0

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <sdkhooks>

#pragma newdecls required

EngineVersion g_Game;
bool g_bIsEnabled[MAXPLAYERS + 1];
int g_inScopeValue = 0;
bool g_bPlayerScope[MAXPLAYERS + 1];
char g_sScope_Flag[32];

Handle sm_allscope_flag = INVALID_HANDLE;

public Plugin myinfo = 
{
	name = "All weapon scope",
	author = "Levi2288",
	description = "add scope function to all weapons",
	version = "1.0",
	url = "https://github.com/Levi2288"
};

char BlockedWeaponsList[][] =
{
	"weapon_aug", "weapon_knife", "weapon_awp", "weapon_ssg08", "weapon_sg556", "weapon_c4", "weapon_taser", "weapon_flashbang", "weapon_hegrenade",
	"weapon_incgrenade", "weapon_molotov", "weapon_decoy", "weapon_smokegrenade", "weapon_healthshot", "weapon_tagrenade", "weapon_knifegg", "weapon_glock", "	weapon_usp_silencer"
};

public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO && g_Game != Engine_CSS)
	{
		SetFailState("This plugin is for CSGO/CSS only.");	
	}
	
	sm_allscope_flag = CreateConVar("sm_allscope_flag", "", "admin flag for donators menu (empty for all players)");
	RegConsoleCmd("sm_allscope", Allscope);
	HookEvent("weapon_fire", Event_OnFire);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponSwitch, SDKOnWeaponSwitch);

}

public Action SDKOnWeaponSwitch(int client, int weapon)
{
	if(g_bIsEnabled[client])
	{
		SetEntProp(client, Prop_Send, "m_iFOV", 90);
		g_inScopeValue = 0;
	}

}

public void OnConfigsExecuted()
{
	GetConVarString(sm_allscope_flag, g_sScope_Flag, sizeof(g_sScope_Flag));
}

public void Event_OnFire(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	int ammo = GetEntProp(ActiveWeapon, Prop_Send, "m_iClip1");
	
	#if DEBUG == 1
		PrintToChatAll("Ammo Left: %i", ammo);
	#endif
					
	if(g_bIsEnabled[client] && ammo == 1)
	{
		SetEntProp(client, Prop_Send, "m_iFOV", 90);
		g_inScopeValue = 0;
	}
}


public Action Allscope(int client, int args)
{
	if((CheckAdminFlags(client, ReadFlagString(g_sScope_Flag))))
	{
		g_bIsEnabled[client] = !g_bIsEnabled[client];
		if(g_bIsEnabled[client])
		{

			PrintToChat(client, "[\x10AS\x01] All Scope: \x04Enabled");
			g_bPlayerScope[client] = true;
		}
		else
		{
			PrintToChat(client, "[\x10AS\x01] All Scope: \x02Disabled");
		}
	}	
	else 
	{
		PrintToChat(client, "[\x10AS\x01] \x04Access denied");
		
	}
}

public Action OnPlayerRunCmd( int client, int& buttons, int& impulse, float vel[3], float angles[3] , int& weapon)
{
	if(IsFakeClient(client) || !IsPlayerAlive(client) ) 
		return Plugin_Continue;
	
	if(g_bIsEnabled[client])
	{
		char sWeapon[64];
		GetClientWeapon(client, sWeapon, sizeof(sWeapon));
	
		if(GetClientButtons(client) & IN_ATTACK2)
		{
			for(int u = 0; u < sizeof(BlockedWeaponsList); u++)
			{
				if(StrEqual(sWeapon, BlockedWeaponsList[u], false))
				{
					#if DEBUG == 1
						PrintToChatAll("BlackListed Weapon: %s", sWeapon);
					#endif
					return Plugin_Continue;
				}
			}
			if(g_bPlayerScope[client])
			{
				g_inScopeValue = g_inScopeValue + 1;
				if(g_inScopeValue == 1)
				{
					SetEntProp(client, Prop_Send, "m_iFOV", 40);
					g_bPlayerScope[client] = false;
					CreateTimer(0.3, Timer_AllowNextScope, client);
				}
				
				else if(g_inScopeValue == 2)
				{
					SetEntProp(client, Prop_Send, "m_iFOV", 10);
					g_bPlayerScope[client] = false;
					CreateTimer(0.3, Timer_AllowNextScope, client);
				}
				
				else if(g_inScopeValue == 3)
				{
					SetEntProp(client, Prop_Send, "m_iFOV", 90);
					g_inScopeValue = 0;
					g_bPlayerScope[client] = false;
					CreateTimer(0.3, Timer_AllowNextScope, client);
				}
				
				#if DEBUG == 1
					PrintToChatAll("Scope Status: %i", g_inScopeValue);
				#endif
			}
		}
		if(GetClientButtons(client) & IN_RELOAD && g_inScopeValue != 0)
		{
			SetEntProp(client, Prop_Send, "m_iFOV", 90);
			g_inScopeValue = 0;
		}			
	}
	return Plugin_Continue;
}

public Action Timer_AllowNextScope(Handle timer, any client)
{
	g_bPlayerScope[client] = true;
}

bool CheckAdminFlags(int client, int iFlag)
{
	int iUserFlags = GetUserFlagBits(client);
	return (iUserFlags & ADMFLAG_ROOT || (iUserFlags & iFlag) == iFlag);
}