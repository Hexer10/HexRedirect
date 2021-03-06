#include <sourcemod>
#include <sdktools>
#include <SteamWorks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME           "HexRedirect"
#define PLUGIN_VERSION        "<TAG>"

StringMap g_cmdMap;

ConVar gc_sMethod;
ConVar gc_sWebSite;
ConVar gc_sAuth;

char g_sWebSite[64];
char g_sAuth[128];

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
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	//Plugin library
	RegPluginLibrary("HexRedirect");
}

public void OnPluginStart()
{
	gc_sMethod = CreateConVar("sm_redirect_method", "ip", "Redirect method, either 'steam' or 'ip', must me the same as the webscript");
	gc_sWebSite = CreateConVar("sm_redirect_website", "https://www.example.com/redirect.php", "FULL URL to your PHP Script");
	gc_sAuth = CreateConVar("sm_redirect_authtoken", "myrandomstring", "A string that must match the one set in the php script in order to perform POST requests");
	AutoExecConfig();
	
	g_cmdMap = new StringMap();
	ParseConfig();
	
	RegAdminCmd("sm_rredirect", Cmd_Reload, ADMFLAG_GENERIC);
	gc_sMethod.AddChangeHook(Hook_CvarChange);
	gc_sWebSite.AddChangeHook(Hook_CvarChange);
	gc_sAuth.AddChangeHook(Hook_CvarChange);
}

public void OnAllPluginsLoaded()
{
	CreateTimer(1.0, Timer_CreateTables);
}

public void OnConfigsExecuted()
{
	char sMethod[64];
	gc_sMethod.GetString(sMethod, sizeof sMethod);
	GetMethod(sMethod);
	
	gc_sWebSite.GetString(g_sWebSite, sizeof g_sWebSite);
	gc_sAuth.GetString(g_sAuth, sizeof g_sAuth);
}

//Hooks
public void Hook_CvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == gc_sMethod)
	{
		GetMethod(newValue);
	}
	else if (convar == gc_sWebSite)
	{
		strcopy(g_sWebSite, sizeof g_sWebSite, newValue);
	}
	else if (convar == gc_sAuth)
	{
		strcopy(g_sAuth, sizeof g_sAuth, newValue);
	}
}


//Commands
public Action Cmd_Reload(int client, int args)
{
	ParseConfig()?
	ReplyToCommand(client, "[SM] Config reloaded successfully!"):
	ReplyToCommand(client, "[SM] Failed to reload the cfg! Check the console/logs for more info.");
	
	return Plugin_Handled;
}


//Events
public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	char sValue[64];
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
	
	DataPack data = new DataPack();
	data.WriteCell(GetClientUserId(client));
	data.WriteString(sValue);

	char sAuth[64];
	if (GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof sAuth) && StrContains(sValue, "{STEAMID}", false) != -1)
	{
		ReplaceString(sValue, sizeof sValue, "{STEAMID}", sAuth, false);
	}
	if (GetClientAuthId(client, AuthId_SteamID64, sAuth, sizeof sAuth) && StrContains(sValue, "{STEAMID64}", false) != -1)
	{
		ReplaceString(sValue, sizeof sValue, "{STEAMID64}", sAuth, false);
	}
	if (GetClientIP(client, sAuth, sizeof sAuth) && StrContains(sValue, "{IP}", false) != -1)
	{
		ReplaceString(sValue, sizeof sValue, "{IP}", sValue);
	}
	
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, g_sWebSite);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "token", sToken);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "url", sValue);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "auth", g_sAuth);
  
	if (!hRequest || !SteamWorks_SetHTTPCallbacks(hRequest, Request_SetURL) || !SteamWorks_SetHTTPRequestContextValue(hRequest, data) || !SteamWorks_SendHTTPRequest(hRequest))
	{
		delete hRequest;
	}
	
	return Plugin_Stop;
}

//HTTP Request callbacks
public void Request_CreateTable(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode)
{
	if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		LogError("Failed to create table! Status code: %i, URL: %s", eStatusCode, g_sWebSite);
	}
	delete hRequest;
}

public void Request_SetURL(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, DataPack data)
{
	data.Reset();
	int client = GetClientOfUserId(data.ReadCell());
	if(!client)
	{
		delete data;
		return;
	}
	
	char sURL[64];
	data.ReadString(sURL, sizeof sURL);
	
	if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		PrintToChat(client, "[SM] Redirect failed to %s! Status code: %i", sURL, eStatusCode);
	}
	else
	{
		PrintToChat(client, "[SM] Redirecting to %s, just click on \"server website\" in the bottom left of the scoreboard.", sURL);
	}
	
	delete data;
	delete hRequest;
}

//Parser callbacks
public SMCResult OnKeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	g_cmdMap.SetString(key, value);
	return SMCParse_Continue;
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

//Timers
public Action Timer_CreateTables(Handle timer)
{
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, g_sWebSite);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "auth", g_sAuth);

	if (!hRequest || !SteamWorks_SetHTTPCallbacks(hRequest, Request_CreateTable) || !SteamWorks_SendHTTPRequest(hRequest))
	{
		LogError("Failed to send request!");
		delete hRequest;
	}
}