#include <sourcemod>
#include <sdktools>
#include <SteamWorks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME           "HexRedirect"
#define PLUGIN_VERSION        "1.1"

StringMap g_cmdMap;

ConVar gc_sMethod;
int g_iMethod;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Hexah",
	description = "",
	version = PLUGIN_VERSION,
	url = "github.com/Hexer10/HexRedirect"
};

//Startup
public void OnPluginStart()
{
	gc_sMethod = CreateConVar("sm_redirect_method", "ip", "Redirect method, either 'steam' or 'ip', must me the same as the webscript");
	AutoExecConfig();
	
	g_cmdMap = new StringMap();
	ParseConfig();
	
	RegAdminCmd("sm_rredirect", Cmd_Reload, ADMFLAG_GENERIC);
	gc_sMethod.AddChangeHook(Hook_CvarChange);
}

public void OnConfigsExecuted()
{
	char sMethod[64];
	gc_sMethod.GetString(sMethod, sizeof sMethod);
	GetMethod(sMethod);
}


//Hooks
public void Hook_CvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetMethod(newValue);
}

//Commands
public Action Cmd_Reload(int client, int args)
{
	ParseConfig()?
	ReplyToCommand(client, "[SM] Config reloaded successfully!"):
	ReplyToCommand(client, "[SM] Failed to reload the cfg! Check the console/logs for more info.");
	
	return Plugin_Handled;
}

public SMCResult OnKeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	g_cmdMap.SetString(key, value);
	return SMCParse_Continue;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	char sValue[64];
	//PrintToConsole(client, sArgs);
	if (!g_cmdMap.GetString(sArgs, sValue, sizeof sValue))
		return Plugin_Continue;
	
	char sToken[64];
	//Use IP
	if (g_iMethod == 0)
	{
		if (!GetClientIP(client, sToken, sizeof sToken))
		{
			PrintToChat(client, "[SM] Failed to get the IP, please try again later.");
			return Plugin_Stop;
		}
	}
	//Use SteamID64
	else if (g_iMethod == 1)
	{
		if (!GetClientAuthId(client, AuthId_SteamID64, sToken, sizeof sToken))
		{
			PrintToChat(client, "[SM] Failed to get the SteamID, please try again later.");
			return Plugin_Stop;
		}
	}
	
	int userid = GetClientUserId(client);
	
	char sURL[512];
	Format(sURL, sizeof(sURL), "https://WEBSITE/redirect.php?token=%s&url=%s", sToken, sValue);
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, sURL);
	
	if (!hRequest || !SteamWorks_SetHTTPCallbacks(hRequest, OnTransferComplete) || !SteamWorks_SetHTTPRequestContextValue(hRequest, userid) || !SteamWorks_SendHTTPRequest(hRequest))
	{
		CloseHandle(hRequest);
	}
	
	PrintToChat(client, "[SM] Redirecting to %s, just click on \"server website\" in the bottom left of the scoreboard.", sValue);
	return Plugin_Stop;
}

public void OnTransferComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid)
{
    if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
    {
		int client = GetClientOfUserId(userid);
		if(IsClientInGame(client))
		{
			PrintToChat(client, "Error setting url");
		}
    }

    CloseHandle(hRequest);
}

//Functions
bool ParseConfig()
{
	g_cmdMap.Clear();
	char sConfig[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfig, sizeof sConfig, "configs/hexredirect.cfg");
	
	SMCParser smc = new SMCParser();
	smc.OnKeyValue = OnKeyValue;
	SMCError error = smc.ParseFile(sConfig);
	if (error != SMCError_Okay)
	{
		LogError("Error occured while parsing the config: %i", error);
		return false;
	}
	return true;
}

void GetMethod(const char[] method)
{
	if (StrEqual(method, "ip", false))
	{
		g_iMethod = 0;
	}
	else if (StrEqual(method, "steam"))
	{
		g_iMethod = 1;
	}
	else
	{
		LogError("Invalid method: %s", method);
	}
}