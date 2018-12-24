//
// My library
//

#if defined _HexRedirect_included
	#endinput
#endif
#define _HexRedirect_included

typeset GetURLCallback 
{
	function void (int client, const char[] url);
	function void (int client, const char[] url, any data);
}

/**
 * Get the current set URL or a NULL_STRING if no URL is set.
 *
 * @param client	Client index.
 * @param callback	Callback.
 * @param any		Extra data value to pass to the callback.
 * @return			True on success, false on failure, if connect to DB is not ready.
 * @error			Invalid client index or client not in game.
 */
native bool HR_GetURL(int client, GetURLCallback callback, any data = 0);

/**
 * Set the current URL, it must be the full url to redirect to.
 *
 * @param client	Client index.
 * @param url		URL to redirect to.
 * @return			True on success, false on failure, if connect to DB is not ready.
 * @error			Invalid client index or client not in game.
 */
native bool HR_SetURL(int client, const char[] url);

public SharedPlugin __pl_HexRedirect =
{
	name = "HexRedirect",
	file = "HexRedirect.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_HexRedirect_SetNTVOptional()
{
	MarkNativeAsOptional("HR_GetURL");
	MarkNativeAsOptional("HR_SetURL");
}
#endif






