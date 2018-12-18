#include <sourcemod>
#include <sdktools>
#include <HexRedirect> 

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME           "HexRedirect"
#define PLUGIN_VERSION        "<TAG>"

Database g_DB;
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
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	//Plugin library
	RegPluginLibrary("HexRedirect");
	
	//Natives
	CreateNative("HR_GetURL", Native_GetURL);
	CreateNative("HR_SetURL", Native_SetURL);
}

public void OnPluginStart()
{
	gc_sMethod = CreateConVar("sm_redirect_method", "ip", "Redirect method, either 'steam' or 'ip', must me the same as the webscript");
	AutoExecConfig();
	
	Database.Connect(Connect_CallBack, "hexredirect");
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
	
	
	char sQuery[512];
	g_DB.Format(sQuery, sizeof sQuery, "INSERT INTO redirects (token, url) \
			VALUES ('%s', '%s') \
			ON DUPLICATE KEY UPDATE \
			token = '%s', \
			url = '%s', \
			time = CURRENT_TIMESTAMP", sToken, sValue, sToken, sValue);
	
	g_DB.Query(Query_Null, sQuery);
	PrintToChat(client, "[SM] Redirecting to %s, just click on \"server website\" in the bottom left of the scoreboard.", sValue);
	return Plugin_Stop;
}

//Commands
public Action Cmd_Reload(int client, int args)
{
	ParseConfig()?
	ReplyToCommand(client, "[SM] Config reloaded successfully!"):
	ReplyToCommand(client, "[SM] Failed to reload the cfg! Check the console/logs for more info.");
	
	return Plugin_Handled;
}

//SQL Callbacks
public void Connect_CallBack(Database db, const char[] error, any data)
{
	if (db == null)
		SetFailState("Connection to databse failed: %s", error);
	
	db.Query(Query_Null, "CREATE TABLE IF NOT EXISTS redirects ( \
			token varchar(64) NOT NULL UNIQUE, \
			url longtext NOT NULL, \
			time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP \
			)");
	
	g_DB = db;
	
}

public void Query_GetURL(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if (results == null)
	{
		LogError("(Get URL)Query failed: %s error", error);
		return;
	}
	
	data.Reset();
	int client = data.ReadCell();
	Handle plugin = data.ReadCell();
	Function callback = data.ReadFunction();
	
	if (results.RowCount == 0)
	{
		Call_StartFunction(plugin, callback);
		Call_PushCell(client);
		Call_PushString(NULL_STRING);
		Call_PushCell(data);
		Call_Finish();
	}
	else
	{
		results.FetchRow();
		int len = results.FetchSize(0);
		char[] sURL = new char[++len];
		results.FetchString(0, sURL, len);
		
		Call_StartFunction(plugin, callback);
		Call_PushCell(client);
		Call_PushString(sURL);
		Call_PushCell(data);
		Call_Finish();
	}
	delete plugin;
	delete data;
}

public void Query_Null(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("Query failed: %s error", error);
		return;
	}
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

//Natives
public int Native_GetURL(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}
	
	if (!IsClientConnected(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	}
	
	if (g_DB == null)
		return false;
		
	char sToken[64];
	//Use IP
	if (g_iMethod == 0 && !GetClientIP(client, sToken, sizeof sToken))
	{
		return false;
	}
	//Use SteamID64
	else if (g_iMethod == 1 && !GetClientAuthId(client, AuthId_SteamID64, sToken, sizeof sToken))
	{
		return false;
	}
	
	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(plugin);
	pack.WriteFunction(GetNativeFunction(2));
	pack.WriteCell(GetNativeCell(3));
	
	char sQuery[512];
	g_DB.Format(sQuery, sizeof sQuery, "SELECT url FROM redirects WHERE token = '%s'", sToken);
			
	g_DB.Query(Query_GetURL, sQuery, pack);
	return true;
}

public int Native_SetURL(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}
	
	if (!IsClientConnected(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	}
	
	if (g_DB == null)
		return false;
		
	char sToken[64];
	//Use IP
	if (g_iMethod == 0 && !GetClientIP(client, sToken, sizeof sToken))
	{
		return false;
	}
	//Use SteamID64
	else if (g_iMethod == 1 && !GetClientAuthId(client, AuthId_SteamID64, sToken, sizeof sToken))
	{
		return false;
	}
	
	int len;
	GetNativeStringLength(2, len);
	
	char[] sURL = new char[++len];
	GetNativeString(2, sURL, len);

	char sQuery[512];
	g_DB.Format(sQuery, sizeof sQuery, "INSERT INTO redirects (token, url) \
			VALUES ('%s', '%s') \
			ON DUPLICATE KEY UPDATE \
			token = '%s', \
			url = '%s', \
			time = CURRENT_TIMESTAMP", sToken, sURL, sToken, sURL);
			
	g_DB.Query(Query_Null, sQuery);
	return true;
}