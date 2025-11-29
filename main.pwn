/* Includes */
#define TIMER_BOMBOMCAR 		10			// Timer
#define CGEN_MEMORY 190000
#define YSI_NO_HEAP_MALLOC
#define MAX_HUD_INFO 6 // atau sesuai jumlah slot HUD kamu


#define NO_SUSPICION_LOGS
#define MAX_COMMANDS 800

#include <a_samp>
#include <a_zones>	
 
#pragma compress 0
#pragma dynamic 7200000   

#pragma warning disable 213, 234, 239, 208, 214, 219, 240

#undef MAX_PLAYERS
#define MAX_PLAYERS 300

#define KEY_VEHICLE_FORWARD 0b001000
#define KEY_VEHICLE_BACKWARD 0b100000

#include <crashdetect>
#include <distance>
#include <streamer>
#include <sscanf2>
#include <a_mysql>
#include <gvar>
#include <chrono>
//#include <progress2>
#include <cps>

// performance issues
// #include <fixes>

//#include <timerfix>
// #include <lookup.inc>
//#include <Pawn.RakNet>
#include <strlib>
#include <easyDialog>
#include <eSelection>
#include <eSelectionv2>
#include <samp_bcrypt>
#include <profiler>

#include <evi>

#include <discord-connector>

#include <YSI_Visual/y_commands>
#include <YSI_Data/y_iterate>
#include <YSI_Coding/y_va>
#include <YSI_Coding/y_timers>
#include <YSI_Game\y_vehicledata>
#include <YSI_Server\y_colours\y_colours_x11def>

#include <nex-ac>
#include <nex-ac_en.lang>
#include <wep-config>

#if !defined SendClientCheck~
	native SendClientCheck(playerid, actionid, memaddr, memOffset, bytesCount);
#endif

#if !defined IsValidVehicle
	native IsValidVehicle(vehicleid);
#endif


forward OnGameModeInitEx();
forward OnPlayerLogin(playerid);
forward OnPlayerDisconnectEx(playerid, reason);
forward OnPlayerDamage(playerid, issuerid, Float:amount, weaponid, bodypart);

//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

public OnGameModeInit()
{
	#if defined DEBUG_MODE
        printf("[debug] OnGameModeInit()");
	#endif

	Profiler_Start();

    // Untuk mengambil waktu saat ini.
    new
        Timestamp:now = Now() + Hours:7,
        outputTime[128]
    ;

    TimeFormat(now, "[%d/%m/%Y %H:%M:%S]", outputTime);
    printf("[OnGameModeInit] Priodest started on: %s (UTC+7)", outputTime);

    print("[OnGameModeInit] Initialising 'Main'...");
    OnGameModeInit_Setup();
	
	SetTimer("UpdateAllHUD", 1000, true); // Update HUD tiap 1 detik
	
	#if defined main_OnGameModeInit
        return main_OnGameModeInit();
    #else
        return 1;
    #endif
	
}
#if defined _ALS_OnGameModeInit
    #undef OnGameModeInit
#else
    #define _ALS_OnGameModeInit
#endif
#define OnGameModeInit main_OnGameModeInit
#if defined main_OnGameModeInit
    forward main_OnGameModeInit();
#endif

#include "Modules/API/Framework.pwn"



// Functions
Float:GetVehicleSpeed(vehicleid)
{
    new
        Float:x,
        Float:y,
        Float:z,
        Float:speed;

    GetVehicleVelocity(vehicleid, x, y, z);
    speed = VectorSize(x, y, z);

    return floatmul(speed, 195.12);
}

SetVehicleSpeed(vehicleid, Float:speed)
{
    if(!IsValidVehicle(vehicleid))
        return 1;

    new Float:vPos[4];

    GetVehicleVelocity(vehicleid,vPos[0],vPos[1],vPos[2]);
    GetVehicleZAngle(vehicleid, vPos[3]);
    speed = floatdiv(speed, 195.12);
    return SetVehicleVelocity(vehicleid, speed * floatsin(-vPos[3], degrees), speed * floatcos(-vPos[3], degrees), (vPos[2]-0.005));
}

stock SetClothingCamera(playerid)
{
	GetPlayerPos(playerid, lX[playerid], lY[playerid], lZ[playerid]);
	GetPlayerFacingAngle(playerid, Degree[playerid]);

	Degree[playerid] += 90.0;
    SelAngle[playerid] = 0.8;

  	static Float: n1X, Float: n1Y;

	n1X = lX[playerid] + Radius * floatcos(Degree[playerid], degrees);
	n1Y = lY[playerid] + Radius * floatsin(Degree[playerid], degrees);

	SetPlayerCameraPos(playerid, n1X, n1Y, lZ[playerid] + Height);
	SetPlayerCameraLookAt(playerid, lX[playerid], lY[playerid], lZ[playerid] + SelAngle[playerid]);
	SetPlayerFacingAngle(playerid, Degree[playerid] - 90);
	TogglePlayerControllable(playerid, false);
	return 1;
}

stock SetClothingCameraRight(playerid)
{
	GetPlayerPos(playerid,lX[playerid],lY[playerid],lZ[playerid]);
	static Float: n1X, Float: n1Y;
	Degree[playerid] += Speed;
	n1X = lX[playerid] + Radius * floatcos(Degree[playerid], degrees);
	n1Y = lY[playerid] + Radius * floatsin(Degree[playerid], degrees);
	SetPlayerCameraPos(playerid, n1X, n1Y, lZ[playerid] + Height);
	SetPlayerCameraLookAt(playerid, lX[playerid], lY[playerid], lZ[playerid]+ SelAngle[playerid]);
	return 1;
}

stock SetClothingCameraLeft(playerid)
{
	GetPlayerPos(playerid,lX[playerid],lY[playerid],lZ[playerid]);
	static Float: n1X, Float: n1Y;
	Degree[playerid] -= Speed;
	n1X = lX[playerid] + Radius * floatcos(Degree[playerid], degrees);
	n1Y = lY[playerid] + Radius * floatsin(Degree[playerid], degrees);
	SetPlayerCameraPos(playerid, n1X, n1Y, lZ[playerid] + Height);
	SetPlayerCameraLookAt(playerid, lX[playerid], lY[playerid], lZ[playerid]+ SelAngle[playerid]);
}

PutPlayerInVehicleEx(playerid, vehicleid, seatid)
{
    if(vehicleid != INVALID_VEHICLE_ID && seatid != 128)
    {
        PlayerData[playerid][pLastVehicle] = vehicleid;
    }

    PutPlayerInVehicle(playerid, vehicleid, seatid);
    return 1;
}

stock GetFactionLockerChannel(factiontype)
{
	new str[24];

	if(factiontype == FACTION_POLICE) format(str, 300, "1316317845990412288");
	else if(factiontype == FACTION_MEDIC) format(str, 300, "1316317845990412288");
	else if(factiontype == FACTION_GOV) format(str, 300, "1316317845990412288");
	else if(factiontype == FACTION_PEDAGANG) format(str, 300, "1316317845990412288");
	else if(factiontype == FACTION_MECHANIC) format(str, 300, "1316317845990412288");
	else format(str, 300, "1316317845990412288");
	return str;
}

// asuransi keliling
ShowAsuransi(playerid)
{
    forex(i, 5)
    {
        TextDrawShowForPlayer(playerid, AsuransiTD[i]);
    }
}

HideAsuransi(playerid)
{
    forex(i, 5)
    {
        TextDrawHideForPlayer(playerid, AsuransiTD[i]);
    }
}	

Function:Main_ShowPlayerFooter(playerid, string[], time, sound)
{
	ShowPlayerFooter(playerid, string, time);
	return 1;
}

Player_ToggleTelportAntiCheat(playerid, bool:toggle)
{
    if (!IsPlayerConnected(playerid))
    {
        return 0;
    }

    EnableAntiCheatForPlayer(playerid, 2, toggle);
    EnableAntiCheatForPlayer(playerid, 3, toggle);
    EnableAntiCheatForPlayer(playerid, 6, toggle); // Code 6 reason.
    return 1;
}

stock SetPlayerLookAt(playerid, Float:x, Float:y)
{
    new Float:Px, Float:Py, Float: Pa;
    GetPlayerPos(playerid, Px, Py, Pa);
    Pa = floatabs(atan((y-Py)/(x-Px)));
    if(x <= Px && y >= Py) Pa = floatsub(180, Pa);
    else if(x < Px && y < Py) Pa = floatadd(Pa, 180);
    else if(x >= Px && y <= Py) Pa = floatsub(360.0, Pa);
    Pa = floatsub(Pa, 90.0);
    if(Pa >= 360.0) Pa = floatsub(Pa, 360.0);
    SetPlayerFacingAngle(playerid, Pa);
}

stock SetPlayerPosEx(playerid, Float:x, Float:y, Float:z, time = 3000)
{
    if(PlayerData[playerid][pFreeze])
    {
        stop PlayerData[playerid][pFreezeTimer];
        PlayerData[playerid][pFreeze] = 0;
        TogglePlayerControllable(playerid, true);
    }
	loadWorld(playerid);
    // Streamer_ToggleIdleUpdate(playerid,1);
    TogglePlayerControllable(playerid, false);
    // Streamer_UpdateEx(playerid, x, y, z);
    SetCameraBehindPlayer(playerid);
    PlayerData[playerid][pFreeze] = 1;
    SetPlayerPos(playerid, x, y, z + 0.5);
    PlayerData[playerid][pFreezeTimer] = defer SetPlayerToUnfreeze[time](playerid);
    Player_ToggleTelportAntiCheat(playerid, true);
    return 1;
} 

ShowPlayerFooter(playerid, string[], time = 3000, title[] = "") {
    if(PlayerData[playerid][pShowFooter]) {
        PlayerTextDrawHide(playerid, PlayerTextdraws[playerid][textdraw_footer][0]);
		PlayerTextDrawHide(playerid, PlayerTextdraws[playerid][textdraw_footer][1]);
		TextDrawHideForPlayer(playerid, FooterTD);
        KillTimer(PlayerData[playerid][pFooterTimer]);
    }
	new str[600];             
	format(str, sizeof(str), "~n~~n~%s", string);
    PlayerTextDrawSetString(playerid, PlayerTextdraws[playerid][textdraw_footer][0], str);
	PlayerTextDrawSetString(playerid, PlayerTextdraws[playerid][textdraw_footer][1], title);
    PlayerTextDrawShow(playerid, PlayerTextdraws[playerid][textdraw_footer][0]);
	PlayerTextDrawShow(playerid, PlayerTextdraws[playerid][textdraw_footer][1]);
	TextDrawShowForPlayer(playerid, FooterTD);
    PlayerData[playerid][pShowFooter] = true;
    PlayerData[playerid][pFooterTimer] = SetTimerEx("HidePlayerFooter", time, false, "d", playerid);

    //if(sound) PlayerPlaySoundEx(playerid, 1085, 1);
    return 1;
}

Function:HidePlayerFooter(playerid) {

    if(!PlayerData[playerid][pShowFooter])
        return 0;

    PlayerData[playerid][pShowFooter] = false;
    KillTimer(PlayerData[playerid][pFooterTimer]);
    PlayerData[playerid][pFooterTimer] = 0;
	TextDrawHideForPlayer(playerid, FooterTD);
    return PlayerTextDrawHide(playerid, PlayerTextdraws[playerid][textdraw_footer][0]), PlayerTextDrawHide(playerid, PlayerTextdraws[playerid][textdraw_footer][1]);
}

Function:WashingMoney(playerid, value)
{
	if(PlayerData[playerid][pActivityTime] >= 100 || GetDirtyMoney(playerid) < 10)
	{
		ClearAnimations(playerid);
		KillTimer(PlayerData[playerid][pActivity]);
		PlayerData[playerid][pActivity] = -1;
		PlayerData[playerid][pActivityTime] = -1;
		HideActivityBarTD(playerid);
	}
	else
	{
		Inventory_Remove(playerid, "Dirty Money", 10);
		GiveMoney(playerid, 15, "Washing money");
		LogPlayerTransaction(playerid, "Washing Money", INVALID_PLAYER_ID, 15);
		PlayerData[playerid][pActivityTime] += value;
		SetActivityBarTDValue(playerid, PlayerData[playerid][pActivityTime]);
	}
}


stock Float:GetPlayerSpeed(playerid)
{
    static
        Float:velocity[3]
    ;

    if(IsPlayerInAnyVehicle(playerid)) {
        GetVehicleVelocity(GetPlayerVehicleID(playerid), velocity[0], velocity[1], velocity[2]);
    }
    else {
        GetPlayerVelocity(GetPlayerVehicleID(playerid), velocity[0], velocity[1], velocity[2]);
    }
    return floatsqroot(floatpower(velocity[0], 2.0) + floatpower(velocity[1], 2.0) + floatpower(velocity[2], 2.0)) * 180.0;
}

IsVehicleDrivingBackwards(vehicleid) // By Joker
{
    new
        Float:Float[3]
    ;
    if(GetVehicleVelocity(vehicleid, Float[1], Float[2], Float[0]))
    {
        GetVehicleZAngle(vehicleid, Float[0]);
        if(Float[0] < 90)
        {
            if(Float[1] > 0 && Float[2] < 0) return true;
        }
        else if(Float[0] < 180)
        {
            if(Float[1] > 0 && Float[2] > 0) return true;
        }
        else if(Float[0] < 270)
        {
            if(Float[1] < 0 && Float[2] > 0) return true;
        }
        else if(Float[1] < 0 && Float[2] < 0) return true;
    }
    return false;
}

stock Float:GetPlayerOnFootSpeed(playerid, bool:kmh = true, Float:velx = 0.0, Float:vely = 0.0, Float:velz = 0.0)
{
    if( velx == 0.0 && vely == 0.0 && velz == 0.0)
        GetPlayerVelocity(playerid, velx, vely, velz);

    return float(floatround((floatsqroot(((velx * velx) + (vely * vely)) + (velz * velz)) * (kmh ? (136.666667) : (85.4166672))), floatround_round));
}

Database_Connect()
{
	g_SQL = mysql_connect(DATABASE_ADDRESS,DATABASE_USERNAME,DATABASE_PASSWORD,DATABASE_NAME);

	if(mysql_errno(g_SQL) != 0){
	    print("[MySQL] - Connection Failed!");
	}
	else{
		print("[MySQL] - Connection Estabilished!");
	}
}

stock IsRoleplayName(player[])
{
    for(new n = 0; n < strlen(player); n++)
    {
        if (player[n] == '_' && player[n+1] >= 'A' && player[n+1] <= 'Z') return 1;
        if (player[n] == ']' || player[n] == '[') return 0;
	}
    return 0;
}

YCMD:netstats(playerid, params[], help)
{
	if (GetAdminLevel(playerid))
	{
		new
			stats[ 512 ]
		;

		GetNetworkStats(stats, sizeof(stats)); // get the servers networkstats
		Dialog_Show(playerid, 0, DIALOG_STYLE_MSGBOX, ""WHITE""SERVER_NAME" "SERVER_LOGO" Server Network Stats", stats, "Close", "");
	}

	return 1;
}

stock GetPlayerRank(playerid) {
	new e_level = PlayerData[playerid][pScore],
		e_str[24];

	if(e_level > 30) {
		e_str = "Supreme Leader";
	}
	else {
		format(e_str, sizeof(e_str), "%s", global_ranks[e_level]);
	}
	return e_str;
}

stock GetPlayerRank2(e_level) {
	new
		e_str[24];

	if(e_level > 30) {
		e_str = "Supreme Leader";
	}
	else {
		format(e_str, sizeof(e_str), "%s", global_ranks[e_level]);
	}
	return e_str;
}

stock IsPlayerNearPlayer(playerid, targetid, Float:radius)
{
	static
		Float:fX,
		Float:fY,
		Float:fZ;

	GetPlayerPos(targetid, fX, fY, fZ);

	return (GetPlayerInterior(playerid) == GetPlayerInterior(targetid) && GetPlayerVirtualWorld(playerid) == GetPlayerVirtualWorld(targetid)) && IsPlayerInRangeOfPoint(playerid, radius, fX, fY, fZ);
}

stock SendNearbyMessage(playerid, Float:radius, color, str[], {Float,_}:...)
{
	static
	    args,
	    start,
	    end,
	    string[144]
	;
	#emit LOAD.S.pri 8
	#emit STOR.pri args

	if (args > 16)
	{
		#emit ADDR.pri str
		#emit STOR.pri start

	    for (end = start + (args - 16); end > start; end -= 4)
		{
	        #emit LREF.pri end
	        #emit PUSH.pri
		}
		#emit PUSH.S str
		#emit PUSH.C 144
		#emit PUSH.C string

		#emit LOAD.S.pri 8
		#emit CONST.alt 4
		#emit SUB
		#emit PUSH.pri

		#emit SYSREQ.C format
		#emit LCTRL 5
		#emit SCTRL 4

        foreach (new i : Player)
		{
			if (IsPlayerNearPlayer(i, playerid, radius) && PlayerData[i][pSpawned])
			{
  				va_SendClientMessage(i, color, string);
			}
		}
		return 1;
	}
	foreach (new i : Player)
	{
		if (IsPlayerNearPlayer(i, playerid, radius) && PlayerData[i][pSpawned])
		{
			va_SendClientMessage(i, color, str);
		}
	}
	return 1;
}

ReturnName(playerid, underscore=1)
{
    new
        name[MAX_PLAYER_NAME + 1];

	if(PlayerData[playerid][pMaskOn] || PlayerData[playerid][pAdminDuty]) format(name, sizeof(name), "%s", PlayerData[playerid][pName]);
	else GetPlayerName(playerid, name, sizeof(name));

    if(!underscore) {
        for (new i = 0, len = strlen(name); i < len; i ++) {
            if(name[i] == '_') name[i] = ' ';
        }
    }

    return name;
}

Function:OnPlayerPasswordChecked(playerid, bool:success)
{
	new str[256], query[256];
    format(str, sizeof(str), "{FFFFFF}Username anda %s telah terdaftar dan aktif pada server ini\nSilahkan masukkan password anda untuk melanjutkan login.\n "YELLOW"(Password salah silahkan masukkan password yang benar.)", ReturnName(playerid));

	if(!success)
	{
		if(++AccountData[playerid][pLoginAttempts] >= 3)
		{
			AccountData[playerid][pLoginAttempts] = 0;
			SendCustomMessage(playerid, "Info", "Kamu telah dikeluarkan dari server karena salah memasukkan kata sandi "YELLOW"kali");
			return KickEx(playerid, 500);
		}
		else
		{
			SendErrorMessage(playerid, "The password you entered is incorrect!");
			Dialog_Show(playerid, LoginScreen, DIALOG_STYLE_PASSWORD, ""WHITE""SERVER_NAME" "SERVER_LOGO" Login", str, "Login", "Quit");
			return 1;
		}
	}

	stop LoginTimer[playerid];
	AccountData[playerid][pLogged] = true;

	format(query, sizeof(query), "SELECT * FROM `users` WHERE `Masters` = '%s' LIMIT %d;", AccountData[playerid][pUsername], MAX_CHARACTERS);
    mysql_tquery(g_SQL, query, "OnQueryFinished", "dd", playerid, THREAD_LIST_CHARACTERS);
	return 1;
}


SQL_SaveAccounts(playerid)
{
    if (!AccountData[playerid][pLogged])
        return 0;

    new
        query[524];

    format(query, sizeof(query), "UPDATE `accounts` SET `kompensasi`='%d',`kompensasiduration`='%d',`kompensasiammount`='%d', `MP` = '%d' WHERE `ID` = '%d'",
		AccountData[playerid][pKompensasi],
		AccountData[playerid][pKompensasiDuration],
		AccountData[playerid][pKompensasiAmmount],
		AccountData[playerid][pMP],
        AccountData[playerid][pID]
    );
    mysql_tquery(g_SQL, query);

    //SQL_SaveCharacter(playerid);
    return 1;
}

Function:ChangePlayerPassword(playerid, hashid)
{
	new
		query[256],
		hash[BCRYPT_HASH_LENGTH];

    bcrypt_get_hash(hash, sizeof(hash));

	mysql_format(g_SQL,query,sizeof(query),"UPDATE `accounts` SET `password` = '%s' WHERE `Username` = '%s'",hash, PlayerData[playerid][pMasters]);
	mysql_query(g_SQL,query, false);
	SendServerMessage(playerid, "Successfully changing your character password!");
	return 1;
}

Function:HashPlayerPassword(playerid, hashid)
{
	new
		query[512],
		hash[BCRYPT_HASH_LENGTH];
		
    bcrypt_get_hash(hash, sizeof(hash));

	GetPlayerName(playerid, AccountData[playerid][pUsername], MAX_PLAYER_NAME + 1);

	mysql_format(g_SQL, query, sizeof(query), "UPDATE `accounts` SET `Username` = '%s', `password` = '%s', `RegisterDate` = '%i', `Registered` = '1', `Active` = 1 WHERE `Username` = '%s'", AccountData[playerid][pUsername], hash, AccountData[playerid][pRegisterDate], ReturnName(playerid));
    mysql_query(g_SQL, query, false);

    SendServerMessage(playerid, "Berhasil Mendaftar!");
	stop LoginTimer[playerid];
    SQL_CheckAccount(playerid);
	return 1;
}

Function:SQL_CheckAccount(playerid)
{
    new query[256];
    format(query, sizeof(query), "SELECT * FROM `accounts` WHERE `Username` = '%s' LIMIT 1;", ReturnName(playerid));
    mysql_tquery(g_SQL, query, "OnQueryFinished", "ddd", playerid, THREAD_FIND_USERNAME, g_MysqlRaceCheck[playerid]);
    return 1;
}

ResetVehicle(vehicleid)
{
    if(1 <= vehicleid <= MAX_VEHICLES)
    {
        if(gToggleSiren[vehicleid])
		{
			gToggleSiren[vehicleid] = false;

			if(IsValidDynamicObject(gSirenObject[vehicleid]))
				DestroyDynamicObject(gSirenObject[vehicleid]);

			gSirenObject[vehicleid] = INVALID_STREAMER_ID;
		}

		#if defined ENABLE_VEHICLE_LABEL
		if(VehicleLabel[vehicleid] != Text3D:INVALID_STREAMER_ID)
			DestroyDynamic3DTextLabel(VehicleLabel[vehicleid]),
			VehicleLabel[vehicleid] = Text3D:INVALID_STREAMER_ID;
		#endif

		if(vTaxiSign[vehicleid] != INVALID_OBJECT_ID) DestroyDynamicObject(vTaxiSign[vehicleid]);

		vTaxiSign[vehicleid] = INVALID_OBJECT_ID;
        CoreVehicles[vehicleid][vehRepair] = false;
        CoreVehicles[vehicleid][vehWood] = 0;

        KillTimer(FlashTime[vehicleid]);
    }
    return 1;
}

stock SQL_SaveCharacter(playerid, params = 0)
{
	static
        query[2098];

	if(GetPlayerState(playerid) != PLAYER_STATE_SPECTATING)
    {
		/*if (GetPVarInt(playerid, "IsAtEvent") != 0(playerid)) {
            ResetEventWeapons(playerid);
            eventTeams[playerid] = TEAM_NONE;
            SetPlayerTeam(playerid, NO_TEAM);
        }
		else {*/
            PlayerData[playerid][pInterior] = GetPlayerInterior(playerid);
            PlayerData[playerid][pWorld] = GetPlayerVirtualWorld(playerid);

            GetPlayerPos(playerid, PlayerData[playerid][pPos][0], PlayerData[playerid][pPos][1], PlayerData[playerid][pPos][2]);
            //GetPlayerFacingAngle(playerid, PlayerData[playerid][pPos][3]);

            //GetPlayerHealth(playerid, PlayerData[playerid][pHealth]);
            //GetPlayerArmour(playerid, PlayerData[playerid][pArmor]);
        //}
    }

	if(params == 1)
	{
		mysql_tquery(g_SQL, sprintf("UPDATE `users` SET `Online` = '0' WHERE `pID` = %d", PlayerData[playerid][pID]));
	}
	PlayerData[playerid][pLastLogOut] = (gettime() + 21600);

	//
	format(query, sizeof(query), "UPDATE `users` SET ");
	format(query, sizeof(query), "%s`PosX`='%f', ", query, PlayerData[playerid][pPos][0]);
    format(query, sizeof(query), "%s`PosY`='%f', ", query, PlayerData[playerid][pPos][1]);
    format(query, sizeof(query), "%s`PosZ`='%f', ", query, PlayerData[playerid][pPos][2]);
	format(query, sizeof(query), "%s`Health` = '%.4f', ", query, PlayerData[playerid][pHealth]);
	format(query, sizeof(query), "%s`Armor`='%f', ", query, PlayerData[playerid][pArmor]);
	format(query, sizeof(query), "%s`World` = '%d', ", query, PlayerData[playerid][pWorld]);
	format(query, sizeof(query), "%s`DutyTime` = '%d', ", query, PlayerData[playerid][pDutyTime]);
	format(query, sizeof(query), "%s`Interior` = '%d', ", query, PlayerData[playerid][pInterior]);
	format(query, sizeof(query), "%s`LoginDate` = '%d', ", query, PlayerData[playerid][pLoginDate]);
	format(query, sizeof(query), "%s`Age` = '%s', ", query, SQL_ReturnEscaped(PlayerData[playerid][pAge]));
	format(query, sizeof(query), "%s`Heigth` = '%d', ", query, PlayerData[playerid][pHeigth]);
	format(query, sizeof(query), "   %s`Gender` = '%d', ", query, PlayerData[playerid][pGender]);
	format(query, sizeof(query), "%s`Injured` = '%d', ", query, PlayerData[playerid][pInjured]);
	format(query, sizeof(query), "%s`InjuredTime` = '%d', ", query, PlayerData[playerid][pInjuredTime]);
	format(query, sizeof(query), "%s`Skin` = '%d', ", query, PlayerData[playerid][pSkin]);
	format(query, sizeof(query), "%s`Bank` = '%d', ", query, PlayerData[playerid][pBank]);
	format(query, sizeof(query), "%s`Salary` = '%d', ", query, PlayerData[playerid][pSalary]);
	format(query, sizeof(query), "%s`Level` = '%d', ", query, PlayerData[playerid][pScore]);
	format(query, sizeof(query), "%s`Hunger` = '%f', ", query, PlayerData[playerid][pHunger]);
	format(query, sizeof(query), "%s`Thirst` = '%f', ", query, PlayerData[playerid][pThirst]);
	format(query, sizeof(query), "%s`SIMA`='%d', ", query, PlayerData[playerid][pLicenseTime][0]);
	format(query, sizeof(query), "%s`SIMB` = '%d', ", query, PlayerData[playerid][pLicenseTime][1]);
	format(query, sizeof(query), "%s`SIMC` = '%d', ", query, PlayerData[playerid][pLicenseTime][2]);
	format(query, sizeof(query), "%s`WEAPLIC` = '%d', ", query, PlayerData[playerid][pLicenseTime][3]);
	format(query, sizeof(query), "%s`Warrants` = '%d', ", query, PlayerData[playerid][pWarrants]);
	format(query, sizeof(query), "%s`Warehouse` = '%d', ", query, PlayerData[playerid][pWarehouse]);
	format(query, sizeof(query), "%s`WarehouseTime` = '%d', ", query, PlayerData[playerid][pWarehouseTime]);
	format(query, sizeof(query), "%s`CarstealingDelay` = '%d', ", query, PlayerData[playerid][pCarStealingDelay]);
	format(query, sizeof(query), "%s`TogBoombox` = '%d', ", query, PlayerData[playerid][pTogBoombox]);
	format(query, sizeof(query), "%s`TogLogin` = '%d', ", query, PlayerData[playerid][pTogLogin]);
	format(query, sizeof(query), "%s`TogLevel` = '%d', ", query, PlayerData[playerid][pTogLevel]);
	format(query, sizeof(query), "%s`Love` = '%f', ", query, PlayerData[playerid][pLove]);
	format(query, sizeof(query), "%s`Status` = '%f', ", query, PlayerData[playerid][pStatus]);
	format(query, sizeof(query), "%s`PartnerName` = '%d', ", query, PlayerData[playerid][pPartnerName]);
	format(query, sizeof(query), "%s`PartnerID` = '%d', ", query, PlayerData[playerid][pPartnerID]);
	format(query, sizeof(query), "%s`MaskID` = '%d', ", query, PlayerData[playerid][pMaskID]);
	format(query, sizeof(query), "%s`SweeperLevel` = '%d', ", query, PlayerData[playerid][pSweeperLevel]);
	format(query, sizeof(query), "%s`BusLevel` = '%d', ", query, PlayerData[playerid][pBusLevel]);
	format(query, sizeof(query), "%s`TrashmasterLevel` = '%d', ", query, PlayerData[playerid][pTrashmasterLevel]);
	format(query, sizeof(query), "%s`FishingLevel` = '%d', ", query, PlayerData[playerid][pFishingLevel]);
	format(query, sizeof(query), "%s`MissionsLevel` = '%d', ", query, PlayerData[playerid][pMissionsLevel]);
	format(query, sizeof(query), "%s`SweeperStats` = '%f', ", query, PlayerData[playerid][pSweeperStats]);
	format(query, sizeof(query), "%s`BusStats` = '%f', ", query, PlayerData[playerid][pBusDelay]);
	format(query, sizeof(query), "%s`TrashmasterStats` = '%d', ", query, PlayerData[playerid][pTrashmasterDelay]);
	format(query, sizeof(query), "%s`FishingStats` = '%d', ", query, PlayerData[playerid][pFishingDelay]);
	format(query, sizeof(query), "%s`MissionsStats` = '%d', ", query, PlayerData[playerid][pMissionsDelay]);
	forex(i, 7)
	{
		mysql_format(g_SQL, query, sizeof(query), "%s`Bullet%d` = '%d', ", query, i + 1, PlayerData[playerid][pBullets][i]);
	}
	format(query, sizeof(query), "%s`Starterpack` = '%d' ", query, PlayerData[playerid][pStarterpack]);
	format(query, sizeof(query), "%sWHERE `pID`= '%d'", query, PlayerData[playerid][pID]);
	mysql_tquery(g_SQL, query);

	//
	format(query, sizeof(query), "UPDATE `users` SET ");
	format(query, sizeof(query), "%s`Entrance` = '%d', ", query, PlayerData[playerid][pEntrance]);
	format(query, sizeof(query), "%s`Business` = '%d', ", query, PlayerData[playerid][pBusiness]);
	format(query, sizeof(query), "%s`House` = '%d', ", query, PlayerData[playerid][pHouse]);
	format(query, sizeof(query), "%s`Job` = '%d', ", query, PlayerData[playerid][pJob]);
	format(query, sizeof(query), "%s`Faction` = '%d', ", query, PlayerData[playerid][pFaction]);
	format(query, sizeof(query), "%s`FactionID` = '%d', ", query, PlayerData[playerid][pFactionID]);
	format(query, sizeof(query), "%s`FactionRank` = '%d', ", query, PlayerData[playerid][pFactionRank]);
	format(query, sizeof(query), "%s`OnDuty` = '%d', ", query, PlayerData[playerid][pOnDuty]);
	format(query, sizeof(query), "%s`FactionDutyTime` = '%d', ", query, PlayerData[playerid][pFactionDutyTime]);
	format(query, sizeof(query), "%s`Clothing` = '%d', ", query, PlayerData[playerid][pClothing]);
	format(query, sizeof(query), "%s`Number` = '%d', ", query, PlayerData[playerid][pNumber]);
	format(query, sizeof(query), "%s`Credits` = '%d', ", query, PlayerData[playerid][pCredits]);
	format(query, sizeof(query), "%s`Exp` = '%d', ", query, PlayerData[playerid][pExp]);
	format(query, sizeof(query), "%s`Paycheck` = '%d', ", query, PlayerData[playerid][pPaycheck]);
	format(query, sizeof(query), "%s`Arrest` = '%d', ", query, PlayerData[playerid][pArrest]);
	format(query, sizeof(query), "%s`JailTime` = '%d', ", query, PlayerData[playerid][pJailTime]);
	format(query, sizeof(query), "%s`JailReason` = '%s', ", query, SQL_ReturnEscaped(PlayerData[playerid][pJailReason]));
	format(query, sizeof(query), "%s`JailBy` = '%s', ", query, SQL_ReturnEscaped(PlayerData[playerid][pJailBy]));
	format(query, sizeof(query), "%s`TweetName`='%s', ", query, SQL_ReturnEscaped(PlayerData[playerid][pTweetName]));
	format(query, sizeof(query), "%s`Frequency`='%d', ", query, PlayerData[playerid][pFrequency]);
	format(query, sizeof(query), "%s`AskPoint` = '%d', ", query, PlayerData[playerid][pAskPoint]);
	format(query, sizeof(query), "%s`Tied` = '%d', ", query, PlayerData[playerid][pTied]);
	format(query, sizeof(query), "%s`FightStyle` = '%d',", query, PlayerData[playerid][pFightStyle]);
	format(query, sizeof(query), "%s`Cuffed` = '%d', ", query, PlayerData[playerid][pCuffed]);
	format(query, sizeof(query), "%s`Rekening` = '%d', ", query, PlayerData[playerid][pRekening]);
	format(query, sizeof(query), "%s`Stress` = '%f', ", query, PlayerData[playerid][pStress]);
	format(query, sizeof(query), "%s`ReportPoint` = '%d', ", query, PlayerData[playerid][pReportPoint]);
	format(query, sizeof(query), "%s`Flat` = '%d', ", query, PlayerData[playerid][pFlat]);
	format(query, sizeof(query), "%s`Bpjs` = '%d', ", query, PlayerData[playerid][pBPJS]);
	format(query, sizeof(query), "%s`BpjsTime` = '%d', ", query, PlayerData[playerid][pBPJSTime]);
	format(query, sizeof(query), "%s`Masters` = '%s', ", query, SQL_ReturnEscaped(PlayerData[playerid][pMasters]));
	format(query, sizeof(query), "%s`HoldWeapon` = '%d', ", query, PlayerData[playerid][pHoldWeapon]);
	format(query, sizeof(query), "%s`LastLogOut` = '%d', ", query, PlayerData[playerid][pLastLogOut]);
	format(query, sizeof(query), "%s`PlayingHours` = '%d', ", query, PlayerData[playerid][pPlayingHours]);
	format(query, sizeof(query), "%s`Minute` = '%d', ", query, PlayerData[playerid][pMinute]);
	format(query, sizeof(query), "%s`HudMode` = '%d', ", query, PlayerData[playerid][pHudMode]);
	format(query, sizeof(query), "%s`VIP` = '%d', ", query, PlayerData[playerid][pVIP]);
	format(query, sizeof(query), "%s`VIPTime` = '%d', ", query, PlayerData[playerid][pVIPTime]);
	format(query, sizeof(query), "%s`Gold` = '%d', ", query, PlayerData[playerid][pGold]);
	format(query, sizeof(query), "%s`ChangePhone` = '%d', ", query, PlayerData[playerid][pChangePhone]);
	format(query, sizeof(query), "%s`JobDelay` = '%d', ", query, PlayerData[playerid][pJobDelay]);
	format(query, sizeof(query), "%s`JobSkin` = '%d', ", query, PlayerData[playerid][pJobSkin]);
	format(query, sizeof(query), "%s`BusDelay` = '%d', ", query, PlayerData[playerid][pBusDelay]);
	format(query, sizeof(query), "%s`SweeperDelay` = '%d', ", query, PlayerData[playerid][pSweeperDelay]);
	format(query, sizeof(query), "%s`TrashmasterDelay` = '%d', ", query, PlayerData[playerid][pTrashmasterDelay]);
	format(query, sizeof(query), "%s`FishingDelay` = '%d', ", query, PlayerData[playerid][pFishingDelay]);
	format(query, sizeof(query), "%s`SmugglerDelay` = '%d',", query, PlayerData[playerid][pSmugglerDelay]);
	format(query, sizeof(query), "%s`MissionsDelay` = '%d',", query, PlayerData[playerid][pMissionsDelay]);
	format(query, sizeof(query), "%s`FactionBadge` = '%d',", query, PlayerData[playerid][pFactionBadge]);
	format(query, sizeof(query), "%s`FactionSkin` = '%d' ", query, PlayerData[playerid][pFactionSkin]);
	format(query, sizeof(query), "%sWHERE `pID`= '%d'", query, PlayerData[playerid][pID]);
	mysql_tquery(g_SQL, query);

	//
	format(query, sizeof(query), "UPDATE `users` SET ");
	format(query, sizeof(query), "%s`Entrance` = '%d' ", query, PlayerData[playerid][pEntrance]);
	for (new i = 0; i < 13; i ++)
	{
		format(query, sizeof(query), "%s, `Gun%d` = '%d', `Ammo%d` = '%d'", query, i + 1, PlayerData[playerid][pGuns][i], i + 1, PlayerData[playerid][pAmmo][i]);
	}
	format(query, sizeof(query), "%s, `Entrance` = '%d' ", query, PlayerData[playerid][pEntrance]);
	format(query, sizeof(query), "%sWHERE `pID`= '%d'", query, PlayerData[playerid][pID]);
	mysql_tquery(g_SQL, query);
	return 1;
}

ReturnVehicleHealth(vehicleid)
{
    if(!IsValidVehicle(vehicleid))
        return 0;

    static
        Float:amount;

    GetVehicleHealth(vehicleid, amount);
    return floatround(amount, floatround_round);
}

ShowCharacterMenu(playerid)
{
	ChoseCharacterInformation[playerid][0] = CreatePlayerTextDraw(playerid, 307.000, 69.000, "Ryuu Chuaks");
	PlayerTextDrawLetterSize(playerid, ChoseCharacterInformation[playerid][0], 0.187, 1.098);
	PlayerTextDrawAlignment(playerid, ChoseCharacterInformation[playerid][0], 2);
	PlayerTextDrawColor(playerid, ChoseCharacterInformation[playerid][0], -1);
	PlayerTextDrawSetShadow(playerid, ChoseCharacterInformation[playerid][0], 0);
	PlayerTextDrawSetOutline(playerid, ChoseCharacterInformation[playerid][0], 0);
	PlayerTextDrawBackgroundColor(playerid, ChoseCharacterInformation[playerid][0], 150);
	PlayerTextDrawFont(playerid, ChoseCharacterInformation[playerid][0], 1);
	PlayerTextDrawSetProportional(playerid, ChoseCharacterInformation[playerid][0], 1);
	PlayerTextDrawShow(playerid, ChoseCharacterInformation[playerid][0]);
	ClearPlayerChat(playerid, 20);

	forex(i, 21)
	{
		TextDrawShowForPlayer(playerid, ChoseCharacter[i]);
	}
	SelectCharIndex[playerid] = 0;
	UpdateCharacterInformationTD(playerid);
	SelectTextDraw(playerid, X11_LIGHTBLUE);

	if(CharacterList[playerid][SelectCharIndex[playerid]][0] == EOS)
	{
		SetSpawnInfo(playerid, 0, 59, 2408.1855,1591.7855,30.4131,87.8793, 0, 0, 0, 0, 0, 0);
		SpawnPlayer(playerid);
	}
	else
	{
		SetSpawnInfo(playerid, 0, CharSkin[playerid][0], 2408.1855,1591.7855,30.4131,87.8793, 0, 0, 0, 0, 0, 0);
		SpawnPlayer(playerid);
	}
	return 1;
}

stock HideChoseCharacterTextDraw(playerid)
{
	forex(i, 1)
	{
		PlayerTextDrawHide(playerid, ChoseCharacterInformation[playerid][i]);
	}

	forex(i, 21)
	{
		TextDrawHideForPlayer(playerid, ChoseCharacter[i]);
	}
	return 1;
}
stock UpdateCharacterInformationTD(playerid)
{
	if (CharacterList[playerid][SelectCharIndex[playerid]][0] == EOS)
	{
		PlayerTextDrawSetString(playerid, ChoseCharacterInformation[playerid][0], "Slot_kosong");
	}
	else
	{
		PlayerTextDrawSetString(playerid, ChoseCharacterInformation[playerid][0], sprintf("%s", CharacterList[playerid][SelectCharIndex[playerid]]));
	}
	ApplyAnimation(playerid, "ped", "SEAT_down", 4.1, 0, 0, 0, 1, 0);
	return 1;
}
/*ShowCharacterMenu(playerid)
{
    new character_list[MAX_CHARACTERS * 55], character_count;

	strcat(character_list, ""YELLOW"Select the character you want to play: \t "WHITE"\n");
    for (new i; i != MAX_CHARACTERS; i ++) if(CharacterList[playerid][i][0] != EOS) {
        strcat(character_list, sprintf("%s\t%d\n", CharacterList[playerid][i], CharLevel[playerid][i]));
        character_count++;
    }

    if(character_count < MAX_CHARACTERS)
        strcat(character_list, "<New Character>");

    Dialog_Show(playerid, SelectCharacter, DIALOG_STYLE_TABLIST_HEADERS, ""WHITE""SERVER_NAME" "SERVER_LOGO" Character List", character_list, "Select", "Quit");
    return 1;
}*/


forward OnQueryFinished(extraid, threadid, race_check);
public OnQueryFinished(extraid, threadid, race_check)
{
    if(!IsPlayerConnected(extraid))
        return 0;

    switch (threadid)
    {
		case THREAD_FIND_USERNAME:
		{
			if (race_check != g_MysqlRaceCheck[extraid])
                return KickEx(extraid);

			new active;

			if (cache_num_rows())
			{
				cache_get_value_name_int(0, "ID", AccountData[extraid][pID]);
				cache_get_value_name(0, "DiscordID", AccountData[extraid][pDiscordID]);
				cache_get_value_name(0, "Username", AccountData[extraid][pUsername], 64);
				cache_get_value_name_int(0, "Active", active);
        		cache_get_value_name_int(0, "VerifyCode", tempCode[extraid]);
				cache_get_value_name_bool(0, "kompensasi", AccountData[extraid][pKompensasi]);
				cache_get_value_name_int(0, "kompensasiduration", AccountData[extraid][pKompensasiDuration]);
				cache_get_value_name_int(0, "kompensasiammount", AccountData[extraid][pKompensasiAmmount]);
				cache_get_value_name_int(0, "MP", AccountData[extraid][pMP]);

				//LoginTimer[extraid] = defer LoginTimers(extraid);

				if(active == 0)
				{
					new lstring[512];
					format(lstring, sizeof(lstring), "{ffffff}Username anda %s telah Terverifikasi ke dalam server\nSilahkan masukkan kode verifikasi anda untuk melanjutkan register.", ReturnName(extraid));
					Dialog_Show(extraid, VerifyCode, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Register", lstring, "Verify", "Exit");
				}
				else
				{

					new str[367];
					GameTextForPlayer(extraid, " ", 1000, 4);
					format(str, sizeof(str), "{FFFFFF}Username anda %s telah terdaftar dan aktif pada server ini\nSilahkan masukkan password anda untuk melanjutkan login. {BABABA}(Input below)", ReturnName(extraid));
					Dialog_Show(extraid, LoginScreen, DIALOG_STYLE_PASSWORD, ""WHITE""SERVER_NAME" "SERVER_LOGO" Login", str, "Login", "Exit");
				}

				new ip[20];

				GetPlayerIp(extraid, ip, sizeof(ip));

				foreach(new i: Player)
				{
				 	if(PlayerData[i][pAdmin] > 0 && PlayerData[i][pAdminDuty])
				 	{
				 		va_SendClientMessage(i, COLOR_FADE3, "** %s has joined the server! ID: {FFFFFF}%i {AAAAAA}(IP: {FFFFFF}%s{AAAAAA})", ReturnName(extraid), extraid, ip);
				 	}
				}

				RandomLoginScreen(extraid);
			}
			else
			{
				new str[256];
				format(str, sizeof(str), ""WHITE"Selamat datang di "LIGHTBLUE"%s\n\n"WHITE"Akun-mu belum terdaftar di server, silakan membuat akun di discord resmi Sevolt Roleplay.\n"GREY"Discord: "YELLOW"https://dsc.gg/SevoltRoleplay", SERVER_NAME);
				Dialog_Show(extraid, DIALOG_NONE, DIALOG_STYLE_MSGBOX, ""WHITE""SERVER_NAME" "SERVER_LOGO" Penjaga Gerbang", str, "Tutup", "");
        		KickEx(extraid, 500);
			}
		}
		//
		case THREAD_LIST_CHARACTERS:
		{
			for (new i = 0; i < MAX_CHARACTERS; i ++)
			{
				CharacterList[extraid][i][0] = EOS;
			}
			for (new i = 0; i < cache_num_rows(); i ++)
			{
				cache_get_value_name(i, "Username", CharacterList[extraid][i]);
				cache_get_value_name_int(i, "Level", CharLevel[extraid][i]);
				cache_get_value_name_int(i, "Faction", CharFaction[extraid][i]);
				cache_get_value_name_int(i, "Skin", CharSkin[extraid][i]);
			}
			SetPVarInt(extraid, "ACPBlacklist", 1);

			if(!Blacklist_Check(extraid, "Username", ReturnAdminName(extraid))) {
				ShowCharacterMenu(extraid);
				DeletePVar(extraid, "ACPBlacklist");
			}
		}
		case THREAD_LOAD_CHARACTERS:
        {
			if(cache_num_rows())
			{

				cache_get_value_name(0, "Age", PlayerData[extraid][pAge]);
				cache_get_value_name(0, "Username", PlayerData[extraid][pName]);
				cache_get_value_name(0, "JailReason", PlayerData[extraid][pJailReason]);
				cache_get_value_name(0, "JailBy", PlayerData[extraid][pJailBy]);
				cache_get_value_name(0, "TweetName", PlayerData[extraid][pTweetName]);
				cache_get_value_name(0, "Masters", PlayerData[extraid][pMasters]);
				cache_get_value_name(0, "PartnerName", PlayerData[extraid][pPartnerName], 32);

				cache_get_value_name_float(0, "Armor", PlayerData[extraid][pArmor]);
				cache_get_value_name_float(0, "PosX", PlayerData[extraid][pPos][0]);
				cache_get_value_name_float(0, "PosY", PlayerData[extraid][pPos][1]);
				cache_get_value_name_float(0, "PosZ", PlayerData[extraid][pPos][2]);
				cache_get_value_name_float(0, "Health", PlayerData[extraid][pHealth]);
				cache_get_value_name_float(0, "Hunger", PlayerData[extraid][pHunger]);
				cache_get_value_name_float(0, "Thirst", PlayerData[extraid][pThirst]);
				cache_get_value_name_float(0, "Stress", PlayerData[extraid][pStress]);
				cache_get_value_name_float(0, "Love", PlayerData[extraid][pLove]);
				cache_get_value_name_float(0, "HuntingSkill", PlayerSkill[extraid][pHuntingSkill]);

				cache_get_value_name_int(0, "pID", PlayerData[extraid][pID]);
				cache_get_value_name_int(0, "Admin", PlayerData[extraid][pAdmin]);
				cache_get_value_name_int(0, "AdminDiv", PlayerData[extraid][pAdminDiv]);
				cache_get_value_name_int(0, "DutyTime", PlayerData[extraid][pDutyTime]);
				cache_get_value_name_int(0, "Bank", PlayerData[extraid][pBank]);
				cache_get_value_name_int(0, "Level", PlayerData[extraid][pScore]);
				cache_get_value_name_int(0, "Salary", PlayerData[extraid][pSalary]);
				cache_get_value_name_int(0, "TogBoombox", PlayerData[extraid][pTogBoombox]);
				cache_get_value_name_int(0, "Interior", PlayerData[extraid][pInterior]);
				cache_get_value_name_int(0, "World", PlayerData[extraid][pWorld]);
				cache_get_value_name_int(0, "Heigth", PlayerData[extraid][pHeigth]);
				cache_get_value_name_int(0, "Gender", PlayerData[extraid][pGender]);
				cache_get_value_name_int(0, "Skin", PlayerData[extraid][pSkin]);
				cache_get_value_name_int(0, "Injured", PlayerData[extraid][pInjured]);
				cache_get_value_name_int(0, "InjuredTime", PlayerData[extraid][pInjuredTime]);
				cache_get_value_name_int(0, "Entrance", PlayerData[extraid][pEntrance]);
				cache_get_value_name_int(0, "Business", PlayerData[extraid][pBusiness]);
				cache_get_value_name_int(0, "House", PlayerData[extraid][pHouse]);
				cache_get_value_name_int(0, "Job", PlayerData[extraid][pJob]);
				cache_get_value_name_int(0, "Clothing", PlayerData[extraid][pClothing]);
				cache_get_value_name_int(0, "Number", PlayerData[extraid][pNumber]);
				cache_get_value_name_int(0, "Credits", PlayerData[extraid][pCredits]);
				cache_get_value_name_int(0, "Exp", PlayerData[extraid][pExp]);
				cache_get_value_name_int(0, "Level", PlayerData[extraid][pScore]);
				cache_get_value_name_int(0, "Paycheck", PlayerData[extraid][pPaycheck]);
				cache_get_value_name_int(0, "Arrest", PlayerData[extraid][pArrest]);
				cache_get_value_name_int(0, "JailTime", PlayerData[extraid][pJailTime]);
				cache_get_value_name_int(0, "Faction", PlayerData[extraid][pFaction]);
				cache_get_value_name_int(0, "FactionRank", PlayerData[extraid][pFactionRank]);
				cache_get_value_name_int(0, "FactionID", PlayerData[extraid][pFactionID]);
				cache_get_value_name_int(0, "OnDuty", PlayerData[extraid][pOnDuty]);
				cache_get_value_name_int(0, "FactionDutyTime", PlayerData[extraid][pFactionDutyTime]);
				cache_get_value_name_int(0, "ReportPoint", PlayerData[extraid][pReportPoint]);
				cache_get_value_name_int(0, "AskPoint", PlayerData[extraid][pAskPoint]);
				cache_get_value_name_int(0, "Frequency", PlayerData[extraid][pFrequency]);
				cache_get_value_name_int(0, "Rekening", PlayerData[extraid][pRekening]);
				cache_get_value_name_int(0, "Bpjs", PlayerData[extraid][pBPJS]);
				cache_get_value_name_int(0, "BpjsTime", PlayerData[extraid][pBPJSTime]);
				cache_get_value_name_int(0, "Flat", PlayerData[extraid][pFlat]);
				cache_get_value_name_int(0, "LastLogOut", PlayerData[extraid][pLastLogOut]);
				cache_get_value_name_int(0, "HoldWeapon", PlayerData[extraid][pHoldWeapon]);
				cache_get_value_name_int(0, "PlayingHours", PlayerData[extraid][pPlayingHours]);
				cache_get_value_name_int(0, "Minute", PlayerData[extraid][pMinute]);
				cache_get_value_name_int(0, "VIP", PlayerData[extraid][pVIP]);
				cache_get_value_name_int(0, "VIPTime", PlayerData[extraid][pVIPTime]);
				cache_get_value_name_int(0, "FactionSkin", PlayerData[extraid][pFactionSkin]);
				cache_get_value_name_int(0, "Gold", PlayerData[extraid][pGold]);
				cache_get_value_name_int(0, "ChangePhone", PlayerData[extraid][pChangePhone]);
				cache_get_value_name_int(0, "JobDelay", PlayerData[extraid][pJobDelay]);
				cache_get_value_name_int(0, "JobSkin", PlayerData[extraid][pJobSkin]);
				cache_get_value_name_int(0, "Cuffed", PlayerData[extraid][pCuffed]);
				cache_get_value_name_int(0, "Tied", PlayerData[extraid][pTied]);
				cache_get_value_name_int(0, "FightStyle", PlayerData[extraid][pFightStyle]);
				cache_get_value_name_int(0, "SIMA", PlayerData[extraid][pLicenseTime][0]);
				cache_get_value_name_int(0, "SIMB", PlayerData[extraid][pLicenseTime][1]);
				cache_get_value_name_int(0, "SIMC", PlayerData[extraid][pLicenseTime][2]);
				cache_get_value_name_int(0, "WEAPLIC", PlayerData[extraid][pLicenseTime][3]);
				cache_get_value_name_int(0, "Warrants", PlayerData[extraid][pWarrants]);
				cache_get_value_name_int(0, "CarstealingDelay", PlayerData[extraid][pCarStealingDelay]);
				cache_get_value_name_int(0, "Warehouse", PlayerData[extraid][pWarehouse]);
				cache_get_value_name_int(0, "WarehouseTime", PlayerData[extraid][pWarehouseTime]);
				cache_get_value_name_int(0, "MaskID", PlayerData[extraid][pMaskID]);
				cache_get_value_name_int(0, "BusDelay", PlayerData[extraid][pBusDelay]);
				cache_get_value_name_int(0, "SweeperDelay", PlayerData[extraid][pSweeperDelay]);
				cache_get_value_name_int(0, "TrashmasterDelay", PlayerData[extraid][pTrashmasterDelay]);
				cache_get_value_name_int(0, "FishingDelay", PlayerData[extraid][pFishingDelay]);
				cache_get_value_name_int(0, "SmugglerDelay", PlayerData[extraid][pSmugglerDelay]);
				cache_get_value_name_int(0, "BusLevel", PlayerData[extraid][pBusLevel]);
				cache_get_value_name_int(0, "SweeperLevel", PlayerData[extraid][pSweeperLevel]);
				cache_get_value_name_int(0, "TrashmasterLevel", PlayerData[extraid][pTrashmasterLevel]);
				cache_get_value_name_int(0, "FishingLevel", PlayerData[extraid][pFishingLevel]);
				cache_get_value_name_int(0, "BusStats", PlayerData[extraid][pBusStats]);
				cache_get_value_name_int(0, "SweeperStats", PlayerData[extraid][pSweeperStats]);
				cache_get_value_name_int(0, "TrashmasterStats", PlayerData[extraid][pTrashmasterStats]);
				cache_get_value_name_int(0, "FishingStats", PlayerData[extraid][pFishingStats]);
				cache_get_value_name_int(0, "Starterpack", PlayerData[extraid][pStarterpack]);
                cache_get_value_name_int(0, "PartnerID", PlayerData[extraid][pPartnerID]);
				cache_get_value_name_int(0, "Status", PlayerData[extraid][pStatus]);
				cache_get_value_name_int(0, "LoginDate", PlayerData[extraid][pLoginDate]);
				cache_get_value_name_int(0, "FactionBadge", PlayerData[extraid][pFactionBadge]);
				cache_get_value_name_int(0, "MissionsDelay", PlayerData[extraid][pMissionsDelay]);
				cache_get_value_name_int(0, "Tables", PlayerData[extraid][pTables]);

				cache_get_value_name_int(0, "TogLogin", PlayerData[extraid][pTogLogin]);
				cache_get_value_name_int(0, "TogLevel", PlayerData[extraid][pTogLevel]);

				cache_get_value_name_int(0, "Char_Citizen", PlayerData[playerID][newCitizen]);
				cache_get_value_name_int(0, "Char_CitizenTimer", PlayerData[playerID][newCitizenTimer]);

				forex(i, 13) {
					new query[450];
					format(query, sizeof(query), "Gun%d", i + 1);
					cache_get_value_name_int(0, query, PlayerData[extraid][pGuns][i]);

					format(query, sizeof(query), "Ammo%d", i + 1);
					cache_get_value_name_int(0, query, PlayerData[extraid][pAmmo][i]);
				}

				forex(i, 7)
				{
					new lquery[128];
					format(lquery, sizeof(lquery), "Bullet%d", i + 1);
					cache_get_value_name_int(0, lquery, PlayerData[extraid][pBullets][i]);
				}

				mysql_tquery(g_SQL, sprintf("SELECT * FROM `weaponsettings` WHERE `Owner` = '%d'", PlayerData[extraid][pID]), "OnWeaponsLoaded", "d", extraid);
				mysql_tquery(g_SQL, sprintf("SELECT * FROM `invoices` WHERE `ID` = '%d'", PlayerData[extraid][pID]), "LoadPlayerInvoice", "d", extraid);
				mysql_tquery(g_SQL, sprintf("SELECT * FROM `inventory` WHERE `ID` = '%d'", PlayerData[extraid][pID]), "LoadPlayerItems", "d", extraid);
				mysql_tquery(g_SQL, sprintf("SELECT * FROM `phonecontacts` WHERE PhoneNumber = %i LIMIT %i", PlayerData[extraid][pNumber], GetMaxContactLimitForPlayer()), "LoadPlayerContacts", "i", extraid);
				mysql_tquery(g_SQL, sprintf("SELECT * FROM `clothing` WHERE `owner` = %d", PlayerData[extraid][pID]), "LoadPlayerClothing", "d", extraid);
				mysql_tquery(g_SQL, sprintf("SELECT * FROM `housekeys` WHERE `playerID` = '%d' ORDER BY `playerID` DESC LIMIT %d", PlayerData[extraid][pID], PLAYER_MAX_HOUSE_SHARE_KEYS), "LoadHouseKey", "d", extraid);
				mysql_tquery(g_SQL, sprintf("SELECT * FROM `warehouse` WHERE `ID` = '%d'", PlayerData[extraid][pID]), "OnLoadWareHouse", "d", extraid);
				mysql_tquery(g_SQL, sprintf("UPDATE `users` SET `Online` = '1' WHERE `pID` = %i", PlayerData[extraid][pID]));

				PlayerData[extraid][pLogged] = true;
				CallLocalFunction("OnPlayerLogin", "d", extraid);
			}
		}
	}
	return 1;
}

ClearPlayerChat(playerid, line)
{
    for (new i = 0; i < line; i ++) {
        SendClientMessage(playerid, -1,"");
    }
}
// funcion login ke kota
Function:SpawnTimer(playerid)
{
	if(SQL_IsCharacterLogged(playerid))
    {
		PlayerData[playerid][pSpawned] = true;
		Player_ToggleTelportAntiCheat(playerid, true);
		TogglePlayerSpectating(playerid, false);
		TogglePlayerControllable(playerid, true);
		StopAudioStreamForPlayer(playerid);
		CancelSelectTextDraw(playerid);     

		new start[500];
		new DCC_Embed:embed = DCC_CreateEmbed(.title="Joining Log", .footer_text=sprintf("%s", ReturnDate()));
		format(start, sizeof(start), "**Name:** ```%s```\n**Ucp:** ```%s```", ReturnName(playerid), AccountData[playerid][pUsername]);
		DCC_SetEmbedDescription(embed, start);
		DCC_SendChannelEmbedMessage(DCC_FindChannelById("1441707254968619018"), embed);

		// Kompensasi
		if(AccountData[playerid][pKompensasi])
		{
			if(AccountData[playerid][pKompensasiDuration] >= gettime())
			{
				SendCustomMessage(playerid, "Server", "You have a settlement that you can claim, use it '"RED"/sevoltkompensasi"WHITE"'");
			}
		}


		for(new i = 0; i < MAX_PLAYERS; i++)
		{
			if(PlayerData[i][pTogIDW])
			{
				new name[MAX_PLAYERS + 1];
				// NameTag
				new str[300];

				if(PlayerData[playerid][pMaskOn]) format(name, sizeof(name), "Stranger_#%d", PlayerData[playerid][pMaskID]);
				else format(name, sizeof(name), "%s", ReturnName(playerid));

				format(str, sizeof(str), ""WHITE"%s\nHP: %.1f | VEST: %.1f", name, GetHealth(i), name, GetArmour(i), i);
				if(NameTag[i][playerid] == PlayerText3D:-1) NameTag[i][playerid] = CreatePlayer3DTextLabel(i, str, X11_WHITE, 0.0, 0.0, 0.1, 10.0, playerid, INVALID_VEHICLE_ID, true);
			}
		}

		if(GetFactionType(playerid) == FACTION_POLICE || GetFactionType(playerid) == FACTION_MEDIC || GetFactionType(playerid) == FACTION_PEDAGANG)
        {
			PlayerData[playerid][pJob] = JOB_PENGANGGURAN;
		}
		if(PlayerData[playerid][pFrequency] > MAX_FREQUENCY)
		{
			PlayerData[playerid][pFrequency] = 0;
		}

		SetWeapons(playerid);

		if (PlayerData[playerid][pHoldWeapon] > 0)
		{
			HoldWeapon(playerid, PlayerData[playerid][pHoldWeapon]);
		}
		//
		if (Inventory_HasItem(playerid, "Phone")) {
			if(PlayerData[playerid][pNumber] == -1)
			{
				PlayerData[playerid][pNumber] = random(90000) + 10000;
			}
		}

		// Needs
		SetPlayerScore(playerid, PlayerData[playerid][pScore]);
		SetPlayerStress(playerid, PlayerData[playerid][pStress]);

		// HUD
		ShowPlayerHud(playerid, true);

		//
		SetArmour(playerid, PlayerData[playerid][pArmor]);
		SetHealth(playerid, PlayerData[playerid][pHealth]);
		SetPlayerHunger(playerid, PlayerData[playerid][pHunger]);
		SetPlayerThirst(playerid, PlayerData[playerid][pThirst]);
		SetPlayerStress(playerid, PlayerData[playerid][pStress]);

		// Weather
		if(GetPlayerInterior(playerid)) {
			SetPlayerWeather(playerid, 4);
			SetPlayerTime(playerid, 12, 0);
		}
		else {
			SetPlayerWeather(playerid, current_weather);

			new hour;
			gettime(hour, _, _);
			SetPlayerTime(playerid, hour, 0);
		}

		PlayerData[playerid][pLoginDate] = gettime();

		//Fightstyle set
		SetPlayerFightStyle(playerid);

		if (PlayerData[playerid][pCuffed] || PlayerData[playerid][pTied]) {
			SetPlayerSpecialAction(playerid, SPECIAL_ACTION_CUFFED);
		}

		// Vehicle Loaded
		new query[300];

		mysql_format(g_SQL, query, sizeof(query), "SELECT * FROM `vehicle` WHERE `vehOwner` = '%d' ORDER BY `vehID` ASC", PlayerData[playerid][pID]);
		mysql_tquery(g_SQL, query, "Vehicle_Load", "d", playerid);

		if(PlayerData[playerid][pMaskID] == 0)
		{
			PlayerData[playerid][pMaskID] = random(90000) + 10000;
		}

		// Skin
		if(PlayerData[playerid][pOnDuty])
		{
			SetFactionColor(playerid);
			SetPlayerSkin(playerid, PlayerData[playerid][pFactionSkin]);
		}
		else
		{
			SetPlayerColor(playerid, TEAM_HIT_COLOR);
			SetPlayerSkin(playerid, PlayerData[playerid][pSkin]);
		}

		// Aksesoris
		cl_attachall(playerid);

		PreloadAnimations(playerid);
	}
	return 1;
}
stock InitSegelTextDraw(playerid)
{
    // Inisialisasi semua UI_Segel[playerid][0] sampai [5]
    // Contoh:
    UI_Segel[playerid][0] = CreatePlayerTextDraw(playerid, 270.000, -171.000, "New textdraw");
    PlayerTextDrawLetterSize(playerid, UI_Segel[playerid][0], 0.300, 1.500);
    PlayerTextDrawAlignment(playerid, UI_Segel[playerid][0], 1);
    PlayerTextDrawColor(playerid, UI_Segel[playerid][0], -1);
    PlayerTextDrawSetShadow(playerid, UI_Segel[playerid][0], 1);
    PlayerTextDrawSetOutline(playerid, UI_Segel[playerid][0], 1);
    PlayerTextDrawBackgroundColor(playerid, UI_Segel[playerid][0], 150);
    PlayerTextDrawFont(playerid, UI_Segel[playerid][0], 1);
    PlayerTextDrawSetProportional(playerid, UI_Segel[playerid][0], 1);

    UI_Segel[playerid][1] = CreatePlayerTextDraw(playerid, 430.000, 391.000, "LD_SPAC:white");
    PlayerTextDrawTextSize(playerid, UI_Segel[playerid][1], 129.000, 52.000);
    PlayerTextDrawAlignment(playerid, UI_Segel[playerid][1], 1);
    PlayerTextDrawColor(playerid, UI_Segel[playerid][1], -16777052);
    PlayerTextDrawSetShadow(playerid, UI_Segel[playerid][1], 0);
    PlayerTextDrawSetOutline(playerid, UI_Segel[playerid][1], 0);
    PlayerTextDrawBackgroundColor(playerid, UI_Segel[playerid][1], 255);
    PlayerTextDrawFont(playerid, UI_Segel[playerid][1], 4);
    PlayerTextDrawSetProportional(playerid, UI_Segel[playerid][1], 1);

    UI_Segel[playerid][2] = CreatePlayerTextDraw(playerid, 432.000, 392.000, "LD_BEAT:chit");
    PlayerTextDrawTextSize(playerid, UI_Segel[playerid][2], 18.000, 20.000);
    PlayerTextDrawAlignment(playerid, UI_Segel[playerid][2], 1);
    PlayerTextDrawColor(playerid, UI_Segel[playerid][2], -1);
    PlayerTextDrawSetShadow(playerid, UI_Segel[playerid][2], 0);
    PlayerTextDrawSetOutline(playerid, UI_Segel[playerid][2], 0);
    PlayerTextDrawBackgroundColor(playerid, UI_Segel[playerid][2], 255);
    PlayerTextDrawFont(playerid, UI_Segel[playerid][2], 4);
    PlayerTextDrawSetProportional(playerid, UI_Segel[playerid][2], 1);

    UI_Segel[playerid][3] = CreatePlayerTextDraw(playerid, 441.000, 394.000, "!");
    PlayerTextDrawLetterSize(playerid, UI_Segel[playerid][3], 0.300, 1.500);
    PlayerTextDrawAlignment(playerid, UI_Segel[playerid][3], 2);
    PlayerTextDrawColor(playerid, UI_Segel[playerid][3], 255);
    PlayerTextDrawSetShadow(playerid, UI_Segel[playerid][3], 0);
    PlayerTextDrawSetOutline(playerid, UI_Segel[playerid][3], 0);
    PlayerTextDrawBackgroundColor(playerid, UI_Segel[playerid][3], 150);
    PlayerTextDrawFont(playerid, UI_Segel[playerid][3], 1);
    PlayerTextDrawSetProportional(playerid, UI_Segel[playerid][3], 1);

    UI_Segel[playerid][4] = CreatePlayerTextDraw(playerid, 496.000, 395.000, "KAMU WARGA BARU!");
    PlayerTextDrawLetterSize(playerid, UI_Segel[playerid][4], 0.210, 1.099);
    PlayerTextDrawAlignment(playerid, UI_Segel[playerid][4], 2);
    PlayerTextDrawColor(playerid, UI_Segel[playerid][4], -1);
    PlayerTextDrawSetShadow(playerid, UI_Segel[playerid][4], 0);
    PlayerTextDrawSetOutline(playerid, UI_Segel[playerid][4], 0);
    PlayerTextDrawBackgroundColor(playerid, UI_Segel[playerid][4], 150);
    PlayerTextDrawFont(playerid, UI_Segel[playerid][4], 1);
    PlayerTextDrawSetProportional(playerid, UI_Segel[playerid][4], 1);

    UI_Segel[playerid][5] = CreatePlayerTextDraw(playerid, 500.000, 407.000, "Untuk dapat melakukan aktivitas kriminal, kamu harus menunggu cooldown sesuai waktu yang tertera: 00:54");
    PlayerTextDrawLetterSize(playerid, UI_Segel[playerid][5], 0.160, 0.899);
    PlayerTextDrawTextSize(playerid, UI_Segel[playerid][5], 100.000, 96.000);
    PlayerTextDrawAlignment(playerid, UI_Segel[playerid][5], 2);
    PlayerTextDrawColor(playerid, UI_Segel[playerid][5], -1);
    PlayerTextDrawSetShadow(playerid, UI_Segel[playerid][5], 0);
    PlayerTextDrawSetOutline(playerid, UI_Segel[playerid][5], 0);
    PlayerTextDrawBackgroundColor(playerid, UI_Segel[playerid][5], 150);
    PlayerTextDrawFont(playerid, UI_Segel[playerid][5], 1);
    PlayerTextDrawSetProportional(playerid, UI_Segel[playerid][5], 1);
    // Lanjutkan untuk UI_Segel[playerid][1] sampai [5]
}


// ---- spawn pertama setelah regist
Function:OnPlayerRegister(playerid)
{
	SpawnPlayer(playerid);
	CancelSelectTextDraw(playerid);
	PlayerData[playerid][pLogged] = true;	

	new fullname[MAX_PLAYER_NAME];
	format(fullname, sizeof(fullname), "%s_%s", FirstName[playerid], LastName[playerid]);
    SetPlayerName(playerid, fullname);
	format(NormalName(playerid), MAX_PLAYER_NAME, "%s", fullname);

	PlayerData[playerid][pBank] = START_PLAYER_BANK;
	PlayerData[playerid][pCreatedAccount] = true;

    PlayerData[playerid][pScore] = 1;
    PlayerData[playerid][pMinute] = 0;
    PlayerData[playerid][pHour] = 0;
    PlayerData[playerid][pMinute] = 0;
    PlayerData[playerid][pSecond] = 0;
    PlayerData[playerid][pLogged] = true;
	SetPlayerScore(playerid, PlayerData[playerid][pScore]);

	PlayerData[playerid][pID] = cache_insert_id();
	printf("[ACOUNT] Pemain dengan nama %s, dengan id %d berhasil terdaftar.", ReturnName(playerid), PlayerData[playerid][pID]);

	SendCustomMessage(playerid, "Character", "Halo "YELLOW"%s"WHITE", Welcome to "RED"Sevolt Roleplay"WHITE"!", ReturnName(playerid));
	SendCustomMessage(playerid, "Character", "Ambil Starterpack di dalam Inventory anda.");
	SendCustomMessage(playerid, "Character", "Jangan lupa ambil kendaraan gratis di sisi kiri anda.");
	Inventory_Add(playerid, "Startergift", 19055, 1);

    PlayerData[playerid][pPos][0]  = 1682.8376;
    PlayerData[playerid][pPos][1]  = -2241.0151;
    PlayerData[playerid][pPos][2]  = 13.5469;
    PlayerData[playerid][pWorld]  = 0;
    PlayerData[playerid][pInterior]  = 0;
    SetPlayerTeam(playerid, 255);

	SetWeapons(playerid);
	SetPlayerColor(playerid, 0xFFFFFF00);
	PlayerData[playerid][pSpawned] = true;

	SQL_SaveAccounts(playerid);
    SetCameraBehindPlayer(playerid);
    SetSpawnInfo(playerid, 0, PlayerData[playerid][pSkin], 1218.39,-1814.05,16.59,271.59, 0, 0, 0, 0, 0, 0);
	SetPlayerInteriorEx(playerid, 0);
	SetPlayerVirtualWorldEx(playerid, 0);
    Player_ToggleTelportAntiCheat(playerid, false);

    Streamer_ToggleIdleUpdate(playerid,1);
	TogglePlayerControllable(playerid, 0);
    SetCameraBehindPlayer(playerid);
    PlayerData[playerid][pFreeze] = 1;
	SelectCharIndex[playerid] = -1;
    PlayerData[playerid][pFreezeTimer] = defer SetPlayerToUnfreeze[5000](playerid);
    Player_ToggleTelportAntiCheat(playerid, true);

	StopAudioStreamForPlayer(playerid);
	SetTimerEx("SpawnTimer", 1000, false, "d", playerid);
	
	if (PlayerData[playerid][pScore] == 1)
	{
		PlayerData[playerid][newCitizen] = true;
		PlayerData[playerid][newCitizenTimer] = 600; // 10 menit
		PlayerData[playerid][pSpawned] = true;

		InitSegelTextDraw(playerid);
		for (new i = 0; i < 6; i++) PlayerTextDrawShow(playerid, UI_Segel[playerid][i]);
	}
	if (PlayerData[playerid][pScore] >= 5 && PlayerData[playerid][newCitizen])
	{
		PlayerData[playerid][newCitizen] = false;
		for (new i = 0; i < 6; i++) PlayerTextDrawHide(playerid, UI_Segel[playerid][i]);
	}


	return 1;
}

Function:OnPlayerFailRegister(playerid)
{
	SpawnPlayer(playerid);
	CancelSelectTextDraw(playerid);
	PlayerData[playerid][pLogged] = true;	
	PlayerData[playerid][pCreatedAccount] = true;

	new fullname[MAX_PLAYER_NAME];

	format(fullname, sizeof(fullname), "%s_%s", FirstName[playerid], LastName[playerid]);
    SetPlayerName(playerid, fullname);

	PlayerData[playerid][pBank] = START_PLAYER_BANK;
	PlayerData[playerid][pHealth] = 100;
	PlayerData[playerid][pArmor] = 0;

	printf("[ACOUNT] Pemain dengan nama %s, dengan id %d berhasil terdaftar.", ReturnName(playerid), PlayerData[playerid][pID]);

	SendCustomMessage(playerid, "Character", "Halo "YELLOW"%s"WHITE", Welcome to "RED"Sevolt Roleplay"WHITE"!", ReturnName(playerid));
	SendCustomMessage(playerid, "Character", "Ambil Starterpack di dalam Inventory anda.");
	SendCustomMessage(playerid, "Character", "Jangan lupa ambil kendaraan gratis Faggio anda.");
	Inventory_Add(playerid, "Startergift", 19055, 1);

    UpdatePlayerSkin(playerid, PlayerData[playerid][pSkin]);
    SetPlayerPos(playerid, 1682.8376,-2241.0151,13.5469);

    SetPlayerVirtualWorldEx(playerid, 1);
    SetPlayerInteriorEx(playerid, 0);

    PlayerData[playerid][pPos][0]  = 1682.8376;
    PlayerData[playerid][pPos][1]  = -2241.0151;
    PlayerData[playerid][pPos][2]  = 13.5469;
    PlayerData[playerid][pWorld]  = 0;
    PlayerData[playerid][pInterior]  = 0;
    SetPlayerTeam(playerid, 255);
    UpdatePlayerSkin(playerid, PlayerData[playerid][pSkin]);

	SetHealth(playerid, PlayerData[playerid][pHealth]);
	SetPlayerSkin(playerid, PlayerData[playerid][pSkin]);
	SetPlayerScore(playerid, PlayerData[playerid][pScore]);
	SetWeapons(playerid);
	SetPlayerColor(playerid, 0xFFFFFF00);
	PlayerData[playerid][pSpawned] = true;
	
    SetCameraBehindPlayer(playerid);
	
	SQL_SaveAccounts(playerid);
	SetCameraBehindPlayer(playerid);
    SetSpawnInfo(playerid, 0, PlayerData[playerid][pSkin], 1219.22,-1812.36,16.59,172.11, 0, 0, 0, 0, 0, 0);
	SetPlayerInteriorEx(playerid, 0);
	SetPlayerVirtualWorldEx(playerid,0);
    
	Streamer_ToggleIdleUpdate(playerid,1);
	TogglePlayerControllable(playerid, 0);
    SetCameraBehindPlayer(playerid);
    PlayerData[playerid][pFreeze] = 1;
	SelectCharIndex[playerid] = -1;
    PlayerData[playerid][pFreezeTimer] = defer SetPlayerToUnfreeze[5000](playerid);
    Player_ToggleTelportAntiCheat(playerid, true);

	StopAudioStreamForPlayer(playerid);
	SetTimerEx("SpawnTimer", 1000, false, "d", playerid);
	return 1;
}

Function:LoadServerStatistic()
{
	printf("");
	printf("");
	printf("--------------------------- < Server Statistic > ---------------------------");
	mysql_tquery(g_SQL, "SELECT * FROM `accounts`", "Account_Count", "");
	mysql_tquery(g_SQL, "SELECT * FROM `users`", "Users_Count", "");
	mysql_tquery(g_SQL, "SELECT * FROM `vehicle`", "Vehicless_Count", "");
	mysql_tquery(g_SQL, "SELECT * FROM `blacklist`", "Blacklist_Count", "");
}

Function:Account_Count()
{
	new rows = cache_num_rows();
	printf("Akun Master: (%d)", rows);
}

Function:Users_Count()
{
	new rows = cache_num_rows();
	printf("Karakter Active: (%d)", rows);
}

Function:Vehicless_Count()
{
	new rows = cache_num_rows();
	printf("Kendaraan Pribadi: (%d)", rows);
}

Function:Blacklist_Count()
{
	new rows = cache_num_rows();
	printf("Blacklist Player: (%d)", rows);
}


OnGameModeInit_Setup()
{
	Database_Connect();
	WeatherRotator();

	// Config
	Streamer_MaxItems(STREAMER_TYPE_OBJECT, 990000);
	Streamer_MaxItems(STREAMER_TYPE_CP, 200);
	Streamer_MaxItems(STREAMER_TYPE_MAP_ICON, 2000);
	Streamer_MaxItems(STREAMER_TYPE_PICKUP, 2000);

	for(new playerid = (GetMaxPlayers() - 1); playerid != -1; playerid--)
	{
		Streamer_DestroyAllVisibleItems(playerid, 0);
	}
	Streamer_VisibleItems(STREAMER_TYPE_OBJECT, 1000);

	EnableTirePopping(true );
	EnableStuntBonusForAll(0);
	ShowPlayerMarkers(false);
	DisableInteriorEnterExits();
	ShowNameTags(false);
	SetNameTagDrawDistance(20.0);
	LimitPlayerMarkerRadius(20.0);
	AllowInteriorWeapons(true);
	//ShowPlayerMarkers(PLAYER_MARKERS_MODE_OFF);
	//BlockGarages(true, GARAGE_TYPE_ALL, "");
	ManualVehicleEngineAndLights();
	SetGameModeText(SERVER_REVISION);

	mysql_tquery(g_SQL, "UPDATE `users` SET `Online` = 0 WHERE `Online` = 1");

	//Dynamic
	StreamerConfig();
	CreateGlobalTextdraw();
	CreateMainObject();
	CreatePhoneNotification();
	LoadServerSQLData();

	for (new i; i < sizeof(ColorList); i++) {
        format(color_string, sizeof(color_string), "%s{%06x}%03d %s", color_string, ColorList[i] >>> 8, i, ((i+1) % 16 == 0) ? ("\n") : (""));
    }

	CallLocalFunction("OnGameModeInitEx", "");
	
	//TD KICK
	tdkickbyluxxy1[0] = TextDrawCreate(0.000, 0.000, "LD_SPAC:white");
	TextDrawTextSize(tdkickbyluxxy1[0], 1000000000.000, 100000000.000);
	TextDrawAlignment(tdkickbyluxxy1[0], 1);
	TextDrawColor(tdkickbyluxxy1[0], -16776961);
	TextDrawSetShadow(tdkickbyluxxy1[0], 0);
	TextDrawSetOutline(tdkickbyluxxy1[0], 0);
	TextDrawBackgroundColor(tdkickbyluxxy1[0], 255);
	TextDrawFont(tdkickbyluxxy1[0], 4);
	TextDrawSetProportional(tdkickbyluxxy1[0], 1);

	tdkickbyluxxy1[1] = TextDrawCreate(250.000, 151.000, "LD_SPAC:white");
	TextDrawTextSize(tdkickbyluxxy1[1], 1.200, 150.000);
	TextDrawAlignment(tdkickbyluxxy1[1], 1);
	TextDrawColor(tdkickbyluxxy1[1], -1);
	TextDrawSetShadow(tdkickbyluxxy1[1], 0);
	TextDrawSetOutline(tdkickbyluxxy1[1], 0);
	TextDrawBackgroundColor(tdkickbyluxxy1[1], 255);
	TextDrawFont(tdkickbyluxxy1[1], 4);
	TextDrawSetProportional(tdkickbyluxxy1[1], 1);

	tdkickbyluxxy1[2] = TextDrawCreate(278.000, 166.000, "WARNING");
	TextDrawLetterSize(tdkickbyluxxy1[2], 0.779, 3.500);
	TextDrawAlignment(tdkickbyluxxy1[2], 1);
	TextDrawColor(tdkickbyluxxy1[2], -1);
	TextDrawSetShadow(tdkickbyluxxy1[2], 1);
	TextDrawSetOutline(tdkickbyluxxy1[2], 0);
	TextDrawBackgroundColor(tdkickbyluxxy1[2], 150);
	TextDrawFont(tdkickbyluxxy1[2], 1);
	TextDrawSetProportional(tdkickbyluxxy1[2], 1);

	tdkickbyluxxy1[3] = TextDrawCreate(270.000, 150.000, "!");
	TextDrawLetterSize(tdkickbyluxxy1[3], 0.779, 6.000);
	TextDrawAlignment(tdkickbyluxxy1[3], 1);
	TextDrawColor(tdkickbyluxxy1[3], -1);
	TextDrawSetShadow(tdkickbyluxxy1[3], 1);
	TextDrawSetOutline(tdkickbyluxxy1[3], 0);
	TextDrawBackgroundColor(tdkickbyluxxy1[3], 150);
	TextDrawFont(tdkickbyluxxy1[3], 1);
	TextDrawSetProportional(tdkickbyluxxy1[3], 1);

	tdkickbyluxxy1[4] = TextDrawCreate(388.000, 150.000, "!");
	TextDrawLetterSize(tdkickbyluxxy1[4], 0.779, 6.000);
	TextDrawAlignment(tdkickbyluxxy1[4], 1);
	TextDrawColor(tdkickbyluxxy1[4], -1);
	TextDrawSetShadow(tdkickbyluxxy1[4], 1);
	TextDrawSetOutline(tdkickbyluxxy1[4], 0);
	TextDrawBackgroundColor(tdkickbyluxxy1[4], 150);
	TextDrawFont(tdkickbyluxxy1[4], 1);
	TextDrawSetProportional(tdkickbyluxxy1[4], 1);

	tdkickbyluxxy1[5] = TextDrawCreate(413.000, 152.000, "LD_SPAC:white");
	TextDrawTextSize(tdkickbyluxxy1[5], 1.200, 150.000);
	TextDrawAlignment(tdkickbyluxxy1[5], 1);
	TextDrawColor(tdkickbyluxxy1[5], -1);
	TextDrawSetShadow(tdkickbyluxxy1[5], 0);
	TextDrawSetOutline(tdkickbyluxxy1[5], 0);
	TextDrawBackgroundColor(tdkickbyluxxy1[5], 255);
	TextDrawFont(tdkickbyluxxy1[5], 4);
	TextDrawSetProportional(tdkickbyluxxy1[5], 1);
	//td warn
	tdwarn1[0] = TextDrawCreate(0.000, 0.000, "LD_SPAC:white");
	TextDrawTextSize(tdwarn1[0], 1000000000.000, 100000000.000);
	TextDrawAlignment(tdwarn1[0], 1);
	TextDrawColor(tdwarn1[0], -16776961);
	TextDrawSetShadow(tdwarn1[0], 0);
	TextDrawSetOutline(tdwarn1[0], 0);
	TextDrawBackgroundColor(tdwarn1[0], 255);
	TextDrawFont(tdwarn1[0], 4);
	TextDrawSetProportional(tdwarn1[0], 1);

	tdwarn1[1] = TextDrawCreate(250.000, 151.000, "LD_SPAC:white");
	TextDrawTextSize(tdwarn1[1], 1.200, 150.000);
	TextDrawAlignment(tdwarn1[1], 1);
	TextDrawColor(tdwarn1[1], -1);
	TextDrawSetShadow(tdwarn1[1], 0);
	TextDrawSetOutline(tdwarn1[1], 0);
	TextDrawBackgroundColor(tdwarn1[1], 255);
	TextDrawFont(tdwarn1[1], 4);
	TextDrawSetProportional(tdwarn1[1], 1);

	tdwarn1[2] = TextDrawCreate(278.000, 166.000, "WARNING");
	TextDrawLetterSize(tdwarn1[2], 0.779, 3.500);
	TextDrawAlignment(tdwarn1[2], 1);
	TextDrawColor(tdwarn1[2], -1);
	TextDrawSetShadow(tdwarn1[2], 1);
	TextDrawSetOutline(tdwarn1[2], 0);
	TextDrawBackgroundColor(tdwarn1[2], 150);
	TextDrawFont(tdwarn1[2], 1);
	TextDrawSetProportional(tdwarn1[2], 1);

	tdwarn1[3] = TextDrawCreate(270.000, 150.000, "!");
	TextDrawLetterSize(tdwarn1[3], 0.779, 6.000);
	TextDrawAlignment(tdwarn1[3], 1);
	TextDrawColor(tdwarn1[3], -1);
	TextDrawSetShadow(tdwarn1[3], 1);
	TextDrawSetOutline(tdwarn1[3], 0);
	TextDrawBackgroundColor(tdwarn1[3], 150);
	TextDrawFont(tdwarn1[3], 1);
	TextDrawSetProportional(tdwarn1[3], 1);

	tdwarn1[4] = TextDrawCreate(388.000, 150.000, "!");
	TextDrawLetterSize(tdwarn1[4], 0.779, 6.000);
	TextDrawAlignment(tdwarn1[4], 1);
	TextDrawColor(tdwarn1[4], -1);
	TextDrawSetShadow(tdwarn1[4], 1);
	TextDrawSetOutline(tdwarn1[4], 0);
	TextDrawBackgroundColor(tdwarn1[4], 150);
	TextDrawFont(tdwarn1[4], 1);
	TextDrawSetProportional(tdwarn1[4], 1);

	tdwarn1[5] = TextDrawCreate(413.000, 152.000, "LD_SPAC:white");
	TextDrawTextSize(tdwarn1[5], 1.200, 150.000);
	TextDrawAlignment(tdwarn1[5], 1);
	TextDrawColor(tdwarn1[5], -1);
	TextDrawSetShadow(tdwarn1[5], 0);
	TextDrawSetOutline(tdwarn1[5], 0);
	TextDrawBackgroundColor(tdwarn1[5], 255);
	TextDrawFont(tdwarn1[5], 4);
	TextDrawSetProportional(tdwarn1[5], 1);

	return 1;
}

stock ReturnJobName(playerid)
{
	new str[35];
	if(PlayerData[playerid][pFaction] != -1) format(str, 300, "%s", Faction_ReturnName(playerid));
	else format(str, 35, "%s", Job_ReturnName(PlayerData[playerid][pJob]));
	return str;
}
WeatherRotator()
{
	new h, m, s;

    gettime(h, m, s);

    if (m == 0 && s == 0) {
        //gettime(current_hour, _);

        new nextWeather = random(91);

        if (nextWeather < 70) current_weather = fine_weather_ids[random(sizeof(fine_weather_ids))];
        else current_weather = wet_weather_ids[0];

        foreach(new i : Player) if (GetPlayerInterior(i) == 0) {
            SetPlayerWeather(i, current_weather);
            SetPlayerTime(i, current_hour, 0);
        }
        SendRconCommand(sprintf("weather %d", current_weather));
        SendRconCommand(sprintf("worldtime %02d:00", current_hour));

		//

		harga_salmon = RandomEx(20, 25);
		harga_tuna = RandomEx(20, 25);
		harga_herring = RandomEx(20, 25);
		harga_catfish = RandomEx(20, 25);
		harga_ayam = RandomEx(45, 55);
		harga_susu = RandomEx(30, 35);
		harga_diamond = RandomEx(495, 500);
		harga_gold = RandomEx(80, 90);
		harga_copper = RandomEx(37, 45);
		harga_iron = RandomEx(20, 30);
		harga_Aluminium = RandomEx(20, 30);
		harga_papan  = RandomEx(40, 50);
		harga_minyak  = RandomEx(35, 45);
		harga_botol = RandomEx(5, 10);
		harga_plastik = Random(1, 5);
		Harga_Rice = RandomEx(40, 50);
    	Harga_Corn = RandomEx(40, 50);
    	Harga_Corn = RandomEx(40, 50);
    	Harga_Corn = RandomEx(40, 50);
    	Harga_Corn = RandomEx(40, 50);
    	Harga_Flour = RandomEx(40, 50);
    	Harga_Sambel = RandomEx(40, 50);
		Harga_Sugar = RandomEx(40, 50);

		va_SendClientMessageToAll(X11_LIMEGREEN,"[IKEA]: "WHITE" Harga barang di pasar sudah berubah '"YELLOW"/mprice"WHITE"' untuk melihat harga.");
		va_SendClientMessageToAll(X11_LIMEGREEN,"[PEMERINTAHAN]: "WHITE" Jangan lupa bayar pajak property anda di "YELLOW"BANK LOST SANTOS.");
    }
	return 1;
}

TimeRotator()
{
	if(current_hour < 24)
	{
		current_hour += 1;
	}
	else
	{
		current_hour = 0;
	}

	foreach(new x : Player) if (GetPlayerInterior(x) == 0) {
		SetPlayerTime(x, current_hour, 0);
    }
	SetWorldTime(current_hour);
    SendRconCommand(sprintf("worldtime %02d:00", current_hour));

	//SetTimer("TimeRotator", 1000, false);
	return 1;
}

SaveAll()
{
    new time = GetTickCount();

    foreach(new i : PlayerVehicle)
    {
        Vehicle_Save(i);
    }
    printf("Done save player and rental vehicle data: %d ms", GetTickCount() - time);

    foreach(new i : Player) if(PlayerData[i][pSpawned])
    {
		PlayerData[i][pLastLogOut] = (gettime() + 1800);

        SQL_SaveCharacter(i, 1);
		SQL_SaveAccounts(i);
    }
    printf("Done save player data: %d ms", GetTickCount() - time);

	foreach (new i : WeedPlant) {
        Weed_Save(i);
    }
	printf("Done save weed data: %d ms", GetTickCount() - time);

	foreach (new i : Vips) {
		Vip_Save(i);
	}

	for (new i; i < MAX_HOUSES; i++) if(HouseData[i][houseExists]) {
        House_Save(i);

        for (new id = 0; id != MAX_FURNITURE; id ++) if(FurnitureData[id][furnitureExists] && FurnitureData[id][furnitureHouse] == i) {
            Furniture_Save(id);
        }
    }

	Iter_Clear(Vips);
	printf("Done save vip data: %d ms", GetTickCount() - time);
    printf("Done save all data: %d ms", GetTickCount() - time);
    return 1;
}

MySqlCloseConnection()
{
    mysql_close(g_SQL);
    return 1;
}

public OnGameModeExit()
{
	Profiler_Stop();
	
	mysql_tquery(g_SQL, "UPDATE users SET `Online` = 0");

    SaveAll();

    printf("There are %d players on the server when server down.", Iter_Count(Player));

    foreach(new playerid : Player)
        TerminateConnection(playerid);

    MySqlCloseConnection();
	//MapAndreas_Unload();

    return 1;
}

public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	#if defined DEBUG_MODE
	    printf("[debug] OnPlayerInteriorChange(PID : %d New-Int : %d Old-Int : %d)", playerid, newinteriorid, oldinteriorid);
	#endif

	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

    foreach(new i : Player) if(PlayerData[i][pSpectator] != INVALID_PLAYER_ID && PlayerData[i][pSpectator] == playerid) {
        SetPlayerInteriorEx(i, GetPlayerInterior(playerid));
        SetPlayerVirtualWorldEx(i, GetPlayerVirtualWorld(playerid));

    }

	if(newinteriorid != 0) {
        SetPlayerWeather(playerid, 4);
        SetPlayerTime(playerid, 12, 0);
    }
    else {
        SetPlayerWeather(playerid, current_weather);
        SetPlayerTime(playerid, current_hour, 0);
    }
    return 1;
}

public OnPlayerLogin(playerid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(PlayerData[playerid][pGender] == 0) ShowPassport(playerid);

	if(PlayerData[playerid][pFrequency] > 999)
	{
		PlayerData[playerid][pFrequency] = 0;
	}
	if(PlayerData[playerid][pVIP] > 0)
	{
		if(PlayerData[playerid][pVIPTime] != 0 && PlayerData[playerid][pVIPTime] <= gettime())
		{
			va_SendClientMessage(playerid, X11_PURPLE, "[i] VIP Kamu sekarang kedaluwarsa, Kamu adalah Pemain Normal sekarang, terima kasih telah berdonasi!");
			PlayerData[playerid][pVIP] = 0;
			PlayerData[playerid][pVIPTime] = 0;
		}
	}
	SelectCharIndex[playerid] = -1;
	SetPlayerName(playerid, PlayerData[playerid][pName]);


	// --- Last Exit Spawn / lokasi spawn pada saat lama tidak masuk kota /
	if(gettime() >= PlayerData[playerid][pLastLogOut])
	{
		ShowSpawnSection(playerid);
		SetSpawnInfo(playerid, 255, PlayerData[playerid][pSkin], 1219.22,-1812.36,16.59, 0, WEAPON_FIST, 0, WEAPON_FIST, 0, WEAPON_FIST, 0);
		SetPlayerFacingAngle(playerid,172.11);
		Player_ToggleTelportAntiCheat(playerid, false);
		Streamer_ToggleIdleUpdate(playerid,1);
		//TogglePlayerControllable(playerid, false);
		SetCameraBehindPlayer(playerid);
		SpawnPlayer(playerid);

	}
	// spawn terakhir kali
	else
	{
		SetSpawnInfo(playerid, 255, PlayerData[playerid][pSkin], PlayerData[playerid][pPos][0],PlayerData[playerid][pPos][1] + 3.0 ,PlayerData[playerid][pPos][2] + 1.0, 0, WEAPON_FIST, 0, WEAPON_FIST, 0, WEAPON_FIST, 0);
		Player_ToggleTelportAntiCheat(playerid, false);
		Streamer_ToggleIdleUpdate(playerid,1);
		TogglePlayerControllable(playerid, false);
		SetCameraBehindPlayer(playerid);
		PlayerData[playerid][pFreeze] = 1;
		PlayerData[playerid][pFreezeTimer] = defer SetPlayerToUnfreeze[5000](playerid);
		loadWorld(playerid);
		Player_ToggleTelportAntiCheat(playerid, false);
		SetPlayerInterior(playerid, PlayerData[playerid][pInterior]);
		SetPlayerVirtualWorld(playerid, PlayerData[playerid][pWorld]);
		SpawnPlayer(playerid);
	}
	return 1;
}

ShowSpawnSection(playerid)
{
	new str[700];
	strcat(str, "Name\tReason\tLocation\n");
	strcat(str, ""WHITE"Los Santos International\t"WHITE"Fly into the city using a flight and land at the airport\tLos Santos (LS)\n");
	strcat(str, ""WHITE"Market Station\t"WHITE"Travel into the city by train and stop at Market Station\tLos Santos (LS)\n");
	strcat(str, ""GREY"Rental Motel Room\t"GREY"Wake up from a deep sleep from the motel\t -\n");
	strcat(str, ""WHITE"House\t"WHITE"Wake up from a deep sleep from the house\t -\n");
	strcat(str, ""GREY"Last Exit\t"WHITE"You will be spawn at the last location\t -\n");
	Dialog_Show(playerid, SpawnSection, DIALOG_STYLE_TABLIST_HEADERS, ""WHITE""SERVER_NAME" "SERVER_LOGO" Select Spawn Location", str, "Spawn", "");
	return 1;
}

public OnPlayerConnect(playerid)
{
		#if defined DEBUG_MODE
	    printf("[debug] OnPlayerConnect(PID : %d)", playerid);
	#endif

    if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	LewatClass[playerid] = false;
	
	ResetStatistics(playerid);
	PreloadAnimations(playerid);
	
	va_SendClientMessage(playerid, -1, "[i] Selalu ingat bahwa server ini menggunakan sistem voice only, dilarang keras RP Bisu/Tuli.");
	va_SendClientMessage(playerid, -1, "[i] Selama di dalam server ingatlah aturan pokok Sevolt -> {ffff00}Respect & Good Attitude.");
	va_SendClientMessage(playerid, COLOR_RED, "[Warning] Dilarang keras meniup-niup mic!");
	va_SendClientMessage(playerid, X11_SKYBLUE, "[-] Ini adalah server berbasis suara. Pastikan mikrofon dan headset Anda berfungsi dengan baik!!!");
	va_SendClientMessage(playerid, X11_SKYBLUE, "[-] Menggunakan program ilegal yang dapat merugikan pemain lain akan diblokir secara permanen!!!.");
	va_SendClientMessage(playerid, X11_SKYBLUE, "[-] Sebelum spawn lebih baik menunggu 5 detik agar tidak terjadi Bug terjun.");

	PlayAudioStreamForPlayer(playerid, "https://f.top4top.io/m_2605eian21.mp3");

	if(g_ServerRestart) {
        TextDrawShowForPlayer(playerid, gServerTextdraws[1]);
    }
	if(!IsNameUsed(playerid, ReturnName(playerid))) {

		g_MysqlRaceCheck[playerid] ++;
		ResetPlayerWeapons(playerid);
		CreatePlayerPhoneNotify(playerid);
		SetPlayerColor(playerid, TEAM_HIT_COLOR);
		CreateAllPTextdraw(playerid);
		CreateInjuredTextDraw(playerid);
		SafeCracking_InitPlayer(playerid);
		SetPlayerToggleSpeedTrap(playerid, 0);
		RemoveMainObject(playerid);
		LewatConnect[playerid] = true;

		DeletePVar(playerid, "IsAtEvent");
	}

	else KickEx(playerid);
	
	/////newrhenal/////////
	//bomombcar//
	playerBombomCar[playerid] = INVALID_VEHICLE_ID;
    bombomCarTimer[playerid] = 0;
	bombomCarTimerEnd[playerid] = 0;
	bombomCarTimerValue[playerid] = 0;

    CreatePickup(1239, 23, 363.2925,-2080.8352,7.8359);
    CreateDynamic3DTextLabel("Bombomcar\n{FFFFFF}Gunakan {00FFCD}/startbombomcar & /stopboomcar", -1, 363.2925,-2080.8352,7.8359, 15);

	InfoText[playerid][0] = CreatePlayerTextDraw(playerid, 338.000, 371.000, "Mohon tetap diwarung~n~selama 10 menit 20 detik");
    PlayerTextDrawLetterSize(playerid, InfoText[playerid][0], 0.300, 1.500);
    PlayerTextDrawAlignment(playerid, InfoText[playerid][0], 2);
    PlayerTextDrawColor(playerid, InfoText[playerid][0], -1);
    PlayerTextDrawSetShadow(playerid, InfoText[playerid][0], 0);
    PlayerTextDrawSetOutline(playerid, InfoText[playerid][0], 0);
    PlayerTextDrawBackgroundColor(playerid, InfoText[playerid][0], 150);
    PlayerTextDrawFont(playerid, InfoText[playerid][0], 1);
    PlayerTextDrawSetProportional(playerid, InfoText[playerid][0], 1);
    
	//tdkick
	tdkickbyluxxy2[playerid][0] = CreatePlayerTextDraw(playerid, 250.000, 151.000, "LD_SPAC:white");
	PlayerTextDrawTextSize(playerid, tdkickbyluxxy2[playerid][0], 164.000, 2.200);
	PlayerTextDrawAlignment(playerid, tdkickbyluxxy2[playerid][0], 1);
	PlayerTextDrawColor(playerid, tdkickbyluxxy2[playerid][0], -1);
	PlayerTextDrawSetShadow(playerid, tdkickbyluxxy2[playerid][0], 0);
	PlayerTextDrawSetOutline(playerid, tdkickbyluxxy2[playerid][0], 0);
	PlayerTextDrawBackgroundColor(playerid, tdkickbyluxxy2[playerid][0], 255);
	PlayerTextDrawFont(playerid, tdkickbyluxxy2[playerid][0], 4);
	PlayerTextDrawSetProportional(playerid, tdkickbyluxxy2[playerid][0], 1);

	tdkickbyluxxy2[playerid][1] = CreatePlayerTextDraw(playerid, 270.000, 200.000, "LD_SPAC:white");
	PlayerTextDrawTextSize(playerid, tdkickbyluxxy2[playerid][1], 124.000, 1.200);
	PlayerTextDrawAlignment(playerid, tdkickbyluxxy2[playerid][1], 1);
	PlayerTextDrawColor(playerid, tdkickbyluxxy2[playerid][1], -1);
	PlayerTextDrawSetShadow(playerid, tdkickbyluxxy2[playerid][1], 0);
	PlayerTextDrawSetOutline(playerid, tdkickbyluxxy2[playerid][1], 0);
	PlayerTextDrawBackgroundColor(playerid, tdkickbyluxxy2[playerid][1], 255);
	PlayerTextDrawFont(playerid, tdkickbyluxxy2[playerid][1], 4);
	PlayerTextDrawSetProportional(playerid, tdkickbyluxxy2[playerid][1], 1);

	tdkickbyluxxy2[playerid][2] = CreatePlayerTextDraw(playerid, 336.000, 264.000, "KICKED BY ADMIN");
	PlayerTextDrawLetterSize(playerid, tdkickbyluxxy2[playerid][2], 0.200, 1.200);
	PlayerTextDrawAlignment(playerid, tdkickbyluxxy2[playerid][2], 1);
	PlayerTextDrawColor(playerid, tdkickbyluxxy2[playerid][2], -1);
	PlayerTextDrawSetShadow(playerid, tdkickbyluxxy2[playerid][2], 1);
	PlayerTextDrawSetOutline(playerid, tdkickbyluxxy2[playerid][2], 0);
	PlayerTextDrawBackgroundColor(playerid, tdkickbyluxxy2[playerid][2], 150);
	PlayerTextDrawFont(playerid, tdkickbyluxxy2[playerid][2], 1);
	PlayerTextDrawSetProportional(playerid, tdkickbyluxxy2[playerid][2], 1);

	tdkickbyluxxy2[playerid][3] = CreatePlayerTextDraw(playerid, 250.000, 301.000, "LD_SPAC:white");
	PlayerTextDrawTextSize(playerid, tdkickbyluxxy2[playerid][3], 164.000, 2.200);
	PlayerTextDrawAlignment(playerid, tdkickbyluxxy2[playerid][3], 1);
	PlayerTextDrawColor(playerid, tdkickbyluxxy2[playerid][3], -1);
	PlayerTextDrawSetShadow(playerid, tdkickbyluxxy2[playerid][3], 0);
	PlayerTextDrawSetOutline(playerid, tdkickbyluxxy2[playerid][3], 0);
	PlayerTextDrawBackgroundColor(playerid, tdkickbyluxxy2[playerid][3], 255);
	PlayerTextDrawFont(playerid, tdkickbyluxxy2[playerid][3], 4);
	PlayerTextDrawSetProportional(playerid, tdkickbyluxxy2[playerid][3], 1);

	tdkickbyluxxy2[playerid][4] = CreatePlayerTextDraw(playerid, 298.000, 215.000, "C");
	PlayerTextDrawLetterSize(playerid, tdkickbyluxxy2[playerid][4], 0.209, 2.200);
	PlayerTextDrawAlignment(playerid, tdkickbyluxxy2[playerid][4], 1);
	PlayerTextDrawColor(playerid, tdkickbyluxxy2[playerid][4], -1);
	PlayerTextDrawSetShadow(playerid, tdkickbyluxxy2[playerid][4], 1);
	PlayerTextDrawSetOutline(playerid, tdkickbyluxxy2[playerid][4], 0);
	PlayerTextDrawBackgroundColor(playerid, tdkickbyluxxy2[playerid][4], 150);
	PlayerTextDrawFont(playerid, tdkickbyluxxy2[playerid][4], 1);
	PlayerTextDrawSetProportional(playerid, tdkickbyluxxy2[playerid][4], 1);

	//tdwarn
	tdwarn2[playerid][0] = CreatePlayerTextDraw(playerid, 250.000, 151.000, "LD_SPAC:white");
	PlayerTextDrawTextSize(playerid, tdwarn2[playerid][0], 164.000, 2.200);
	PlayerTextDrawAlignment(playerid, tdwarn2[playerid][0], 1);
	PlayerTextDrawColor(playerid, tdwarn2[playerid][0], -1);
	PlayerTextDrawSetShadow(playerid, tdwarn2[playerid][0], 0);
	PlayerTextDrawSetOutline(playerid, tdwarn2[playerid][0], 0);
	PlayerTextDrawBackgroundColor(playerid, tdwarn2[playerid][0], 255);
	PlayerTextDrawFont(playerid, tdwarn2[playerid][0], 4);
	PlayerTextDrawSetProportional(playerid, tdwarn2[playerid][0], 1);

	tdwarn2[playerid][1] = CreatePlayerTextDraw(playerid, 270.000, 200.000, "LD_SPAC:white");
	PlayerTextDrawTextSize(playerid, tdwarn2[playerid][1], 124.000, 1.200);
	PlayerTextDrawAlignment(playerid, tdwarn2[playerid][1], 1);
	PlayerTextDrawColor(playerid, tdwarn2[playerid][1], -1);
	PlayerTextDrawSetShadow(playerid, tdwarn2[playerid][1], 0);
	PlayerTextDrawSetOutline(playerid, tdwarn2[playerid][1], 0);
	PlayerTextDrawBackgroundColor(playerid, tdwarn2[playerid][1], 255);
	PlayerTextDrawFont(playerid, tdwarn2[playerid][1], 4);
	PlayerTextDrawSetProportional(playerid, tdwarn2[playerid][1], 1);

	tdwarn2[playerid][2] = CreatePlayerTextDraw(playerid, 336.000, 264.000, "ALL STAF KOTA");
	PlayerTextDrawLetterSize(playerid, tdwarn2[playerid][2], 0.200, 1.200);
	PlayerTextDrawAlignment(playerid, tdwarn2[playerid][2], 1);
	PlayerTextDrawColor(playerid, tdwarn2[playerid][2], -1);
	PlayerTextDrawSetShadow(playerid, tdwarn2[playerid][2], 1);
	PlayerTextDrawSetOutline(playerid, tdwarn2[playerid][2], 0);
	PlayerTextDrawBackgroundColor(playerid, tdwarn2[playerid][2], 150);
	PlayerTextDrawFont(playerid, tdwarn2[playerid][2], 1);
	PlayerTextDrawSetProportional(playerid, tdwarn2[playerid][2], 1);

	tdwarn2[playerid][3] = CreatePlayerTextDraw(playerid, 250.000, 301.000, "LD_SPAC:white");
	PlayerTextDrawTextSize(playerid, tdwarn2[playerid][3], 164.000, 2.200);
	PlayerTextDrawAlignment(playerid, tdwarn2[playerid][3], 1);
	PlayerTextDrawColor(playerid, tdwarn2[playerid][3], -1);
	PlayerTextDrawSetShadow(playerid, tdwarn2[playerid][3], 0);
	PlayerTextDrawSetOutline(playerid, tdwarn2[playerid][3], 0);
	PlayerTextDrawBackgroundColor(playerid, tdwarn2[playerid][3], 255);
	PlayerTextDrawFont(playerid, tdwarn2[playerid][3], 4);
	PlayerTextDrawSetProportional(playerid, tdwarn2[playerid][3], 1);

	tdwarn2[playerid][4] = CreatePlayerTextDraw(playerid, 298.000, 215.000, "C");
	PlayerTextDrawLetterSize(playerid, tdwarn2[playerid][4], 0.209, 2.200);
	PlayerTextDrawAlignment(playerid, tdwarn2[playerid][4], 1);
	PlayerTextDrawColor(playerid, tdwarn2[playerid][4], -1);
	PlayerTextDrawSetShadow(playerid, tdwarn2[playerid][4], 1);
	PlayerTextDrawSetOutline(playerid, tdwarn2[playerid][4], 0);
	PlayerTextDrawBackgroundColor(playerid, tdwarn2[playerid][4], 150);
	PlayerTextDrawFont(playerid, tdwarn2[playerid][4], 1);
	PlayerTextDrawSetProportional(playerid, tdwarn2[playerid][4], 1);

		//tdmegaphone
	tdmegaphone[playerid] = CreatePlayerTextDraw(playerid, 250.0, 100.0, "~b~MEGAPHONE AKTIF");
    PlayerTextDrawLetterSize(playerid, tdmegaphone[playerid], 0.3, 1.2);
    PlayerTextDrawAlignment(playerid, tdmegaphone[playerid], 2);
    PlayerTextDrawColor(playerid, tdmegaphone[playerid], -1);
    PlayerTextDrawBackgroundColor(playerid, tdmegaphone[playerid], 255);
    PlayerTextDrawFont(playerid, tdmegaphone[playerid], 2);
    PlayerTextDrawSetProportional(playerid, tdmegaphone[playerid], 1);
    PlayerTextDrawSetShadow(playerid, tdmegaphone[playerid], 1);	
	
	evTeam[playerid] = -1;
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	#if defined DEBUG_MODE
	    printf("[debug] OnPlayerDeath(PID : %d KID : %d Reason : %d)", playerid, killerid, reason);
	#endif

	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	foreach(new ii : Player)
    {
        if(PlayerData[ii][pAdmin] > 0)
        {
            SendDeathMessageToPlayer(ii, killerid, playerid, reason);
        }
    }

    if(killerid != INVALID_PLAYER_ID)
    {
        if(1 <= reason <= 46)
            Log_Save(E_LOG_KILL, sprintf("[%s] %s has killed %s (%s).", ReturnDate(), ReturnName(killerid), ReturnName(playerid), ReturnWeaponName(reason)));

        else
            Log_Save(E_LOG_KILL, sprintf("[%s] %s has killed %s (reason %d).", ReturnDate(), ReturnName(killerid), ReturnName(playerid), reason));

        if(reason == 50 && killerid != INVALID_PLAYER_ID)
            SendAdminMessage(X11_LIGHTGREY, "[Admin Warn] %s telah membunuh %s oleh heli-blading.", ReturnName(killerid, 0), ReturnName(playerid, 0));

        if(reason == 29 && killerid != INVALID_PLAYER_ID && GetPlayerState(killerid) == PLAYER_STATE_DRIVER)
            SendAdminMessage(X11_LIGHTGREY, "[Admin Warn] %s telah membunuh %s oleh driver shooting.", ReturnName(killerid, 0), ReturnName(playerid, 0));

		new start[500];
		new DCC_Embed:embed = DCC_CreateEmbed(.title="KILL LOG", .footer_text=sprintf("%s", ReturnDate()), .thumbnail_url="https://cdn.discordapp.com/attachments/1153994402025451570/1251744178799513670/20231205_153957.png?ex=66817d5c&is=66802bdc&hm=0185e67bd8fc70ee9c3a53e48aea63bd25be9a760451eaa4f3ef8fa574b771d0&");
		format(start, sizeof(start), "%s has killed %s using %s", ReturnName(killerid), ReturnName(playerid), ReturnWeaponName(reason));
		DCC_SetEmbedDescription(embed, start);
		DCC_SendChannelEmbedMessage(DCC_FindChannelById("1441707540734935080"), embed);
    }
	if (GetPVarInt(playerid, "sedangNganter")) 
	{
		if (PlayerData[playerid][pSmugglerPick]) 
		{
		new Float:pos[3];
		GetPlayerPos(playerid, pos[0], pos[1], pos[2]);
		packetObject[selectedLocation] = CreateDynamicObject(1279, pos[0], pos[1], pos[2]-0.9, 0.0, 0.0, 0.0, 0, 0);
		packetLabel[selectedLocation] = CreateDynamic3DTextLabel("[Smungler Packet]\n"WHITE"Press '"GREEN"Y"WHITE"' to pick the packet.", COLOR_CLIENT, pos[0], pos[1], pos[2]+0.5, 7.0, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, -1);
		packetPlayerid[selectedLocation] = INVALID_PLAYER_ID;
		PlayerData[playerid][pSmugglerPick] = 0;
		PlayerData[playerid][pSmugglerFind] = 0;
		DisablePlayerRaceCheckpoint(playerid);
		SendCustomMessage(playerid, "Smuggler", "You've failed store a packet.");
		SetSmugglerDelay(playerid, 300);
		DeletePVar(playerid, "sedangSmuggler");
		DeletePVar(playerid, "sedangNganter");
		}
	}
	if(GetPVarInt(playerid, "IsAtEvent") == 1)
    {
        Zombie_CheckVictory(); // cek kondisi setelah player mati
    }
	// --- TDM ---
    if(IsPlayerInEvent(playerid) && killerid!=INVALID_PLAYER_ID && IsPlayerInEvent(killerid))
    {
        EventData[eventScore][EventTeam[killerid]-1]++;

        if(EventData[eventScore][EventTeam[killerid]-1] >= EventData[eventTargetScore])
        {
            EventData[eventWinner] = EventTeam[killerid];
            va_SendClientMessageToAll(-1, "[TDM] Team %s menang!",
                EventTeam[killerid]==TEAM_A ? "Red" : "Blue");

            foreach(new i:Player)
            {
                if(IsPlayerInEvent(i))
                {
                    if(EventTeam[i]==EventData[eventWinner]) GiveMoney(i, EventData[eventPrize]);
                    else GiveMoney(i, EventData[eventPrizeParticipation]);
                    EventLeave(i);
                }
            }
            static const empty[E_EVENT];
            EventData = empty;
        }
        else
        {
            EventWaitingSpawn[playerid] = true;
        }
    }

    // --- DM ---
    if(IsPlayerInDM(playerid) && killerid!=INVALID_PLAYER_ID && IsPlayerInDM(killerid))
    {
        DMScore[killerid]++;

        if(DMScore[killerid] >= DMData[dmTargetScore])
        {
            new pname[MAX_PLAYER_NAME];
            GetPlayerName(killerid, pname, sizeof(pname));
            va_SendClientMessageToAll(-1, "[DM] Player %s menang dengan %d kill!", pname, DMScore[killerid]);

            foreach(new i:Player)
            {
                if(IsPlayerInDM(i))
                {
                    if(i==killerid) GiveMoney(i, DMData[dmPrize]);
                    else GiveMoney(i, DMData[dmPrizeParticipation]);
                    DMLeave(i);
                }
            }
            static const empty[E_DM_EVENT];
            DMData = empty;
        }
        else
        {
            DMSpawn(playerid); // respawn lagi
        }
    }

	return 1;
}

KickEx(playerid, time = 200)
{
    if(PlayerData[playerid][pKicked])
        return 0;

    PlayerData[playerid][pKicked] = 1;
	SQL_SaveAccounts(playerid);

	defer KickTimer[time](playerid);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	#if defined DEBUG_MODE
	    printf("[debug] OnPlayerDisconnect(PID : %d REASON : %d)", playerid, reason);
	#endif

	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(IsPlayerInAnyVehicle(playerid))
	{
        RemovePlayerFromVehicle(playerid);
    }

	g_MysqlRaceCheck[playerid] ++;

	new start[500], status[500];
	switch(reason)
	{
		case 0:
		{
			status = "timeout/crash";
		}
		case 1:
		{
			status = "Leaving";
		}
		case 2:
		{
			status = "kicked/banned";
		}
	}
	new DCC_Embed:embed = DCC_CreateEmbed(.title="Leaving Log", .footer_text=sprintf("%s", ReturnDate()));
	format(start, sizeof(start), "**Name:** ```%s```\n**Ucp:** ```%s  ```\n**Reason:** ```%s```", ReturnName(playerid), AccountData[playerid][pUsername], status);
	DCC_SetEmbedDescription(embed, start);
	DCC_SendChannelEmbedMessage(DCC_FindChannelById("1441707254968619018"), embed);

	if(PlayerData[playerid][pSpawned]) CreateDisconnectLabel(playerid, reason);

	CallLocalFunction("OnPlayerDisconnectEx", "dd", playerid, reason);
	TerminateConnection(playerid);
	SQL_SaveAccounts(playerid);
	
	GetPlayerHealth(playerid, PlayerData[playerid][pHealth]);
	GetPlayerArmour(playerid, PlayerData[playerid][pArmor]);


	//newrhenal////
	if(playerBombomCar[playerid] != INVALID_VEHICLE_ID)
    {
        DestroyVehicle(playerBombomCar[playerid]);
        playerBombomCar[playerid] = INVALID_VEHICLE_ID;
    }
	if(bombomCarTimer[playerid] != 0)
    {
        KillTimer(bombomCarTimer[playerid]);
        bombomCarTimer[playerid] = 0;
    }
	if(bombomCarTimerEnd[playerid] != 0)
    {
        KillTimer(bombomCarTimerEnd[playerid]);
        bombomCarTimerEnd[playerid] = 0;
    }

	return 1;
}

stock TerminateConnection(playerid)
{
	// Clothing
	SavePlayerClothing(playerid);

	// Private Vehicle
	for(new vid = 0; vid != MAX_PLAYER_VEHICLE; vid++)
	{
        if(Vehicle_IsOwner(playerid, vid) && VehicleData[vid][cFaction] == -1)  {
			Vehicle_Save(vid);
            Vehicle_Reset(vid);
        }
    }

	if(IsValidDynamic3DTextLabel(PlayerData[playerid][pAdminTag]))
		DestroyDynamic3DTextLabel(PlayerData[playerid][pAdminTag]);

	// Masked
	if(PlayerData[playerid][pMaskOn]) {
		Inventory_Add(playerid, "PEDO", 19036);
		SetPlayerName(playerid, PlayerData[playerid][pName]);
        PlayerData[playerid][pMaskOn] = 0;
	}

	// Reset ADO
	if(PlayerData[playerid][pAdoActive]) {
        if(IsValidDynamic3DTextLabel(PlayerData[playerid][pAdoTag]))
            DestroyDynamic3DTextLabel(PlayerData[playerid][pAdoTag]);

        PlayerData[playerid][pAdoTag] = Text3D:INVALID_STREAMER_ID;
    }

	// Player Activity
	if (PlayerData[playerid][pActivityTime] != -1) {
		KillTimer(PlayerData[playerid][pActivity]);
		PlayerData[playerid][pActivity] = -1;
		PlayerData[playerid][pActivityTime] = -1;
	}

	// Taxi
	if(PlayerData[playerid][pTaxiPlayer] != INVALID_PLAYER_ID) {
        LeaveTaxi(playerid, PlayerData[playerid][pTaxiPlayer]);
    }

	// Fuel Update
   	if(PlayerData[playerid][pRefillPrice] > 0) {
        GiveMoney(playerid, -PlayerData[playerid][pRefillPrice], "Bayar bensin");

		LogPlayerTransaction(playerid, "Fuel Price", INVALID_PLAYER_ID, PlayerData[playerid][pRefillPrice]);
	}

	// Caller
 	if(PlayerData[playerid][pCallLine] != INVALID_PLAYER_ID)
    {
        SendCustomMessage(PlayerData[playerid][pCallLine], "Phone", "Panggilan telah berakhir!");

		CallRemoteFunction("SV_CancelCall", "ddd", playerid, PlayerData[playerid][pCallLine], PhoneFreq[playerid]);
		SetTimerEx("LC_CancelCall", 1000, false, "d", playerid);
    }

	// Editing Vehicle Object
	if (PlayerData[playerid][pVObject] != -1 && PlayerData[playerid][pEditingMode] == VEHICLE) {
		if(PlayerTemp[playerid][temp_pivot] != INVALID_STREAMER_ID)
		{
			DestroyDynamicObject(PlayerTemp[playerid][temp_pivot]);
			PlayerTemp[playerid][temp_pivot] = INVALID_STREAMER_ID;
		}
	}

	// Footer
	if(PlayerData[playerid][pShowFooter]) {
        KillTimer(PlayerData[playerid][pFooterTimer]);
    }

	// Boombox
	if(BoomboxData[playerid][boomboxPlaced]) {
        Boombox_Destroy(playerid);
    }

	// Drag
	if (PlayerData[playerid][pDragged])
	    KillTimer(PlayerData[playerid][pDragTimer]);

	// Freezing Player
	if(PlayerData[playerid][pFreeze]) {
        stop PlayerData[playerid][pFreezeTimer];
    }

	// Press Button
	if(PlayerData[playerid][pPressBtn])
		KillTimer(PlayerData[playerid][pPressBtnTime]);

	// Harvest Plant Farmer
	if(PlayerData[playerid][pHarvest] != -1) {
		PlantData[PlayerData[playerid][pHarvest]][PlantHarvest] = 0;
	}

	// ID Player
	foreach (new i : Player)
	{
		if(IsPlayerConnected(i))
		{
			if(PlayerData[i][pTogIDW])
			{
				if(NameTag[i][playerid] == PlayerText3D:-1) DeletePlayer3DTextLabel(i, NameTag[i][playerid]), NameTag[i][playerid] = PlayerText3D:-1;
			}

			if (PlayerData[i][pHouseSeller] == playerid) {
				PlayerData[i][pHouseSeller] = INVALID_PLAYER_ID;
				PlayerData[i][pHouseOffered] = -1;
			}
			if (PlayerData[i][pGarageSeller] == playerid) {
				PlayerData[i][pGarageSeller] = INVALID_PLAYER_ID;
				PlayerData[i][pGarageOffered] = -1;
			}
			if (PlayerData[i][pBusinessSeller] == playerid) {
				PlayerData[i][pBusinessSeller] = INVALID_PLAYER_ID;
				PlayerData[i][pBusinessOffered] = -1;
			}
			if (PlayerData[i][pCarSeller] == playerid) {
				PlayerData[i][pCarSeller] = INVALID_PLAYER_ID;
				PlayerData[i][pCarOffered] = -1;
			}
			if (PlayerData[i][pFriskOffer] == playerid) {
				PlayerData[i][pFriskOffer] = INVALID_PLAYER_ID;
			}
			if (PlayerData[i][pFactionOffer] == playerid) {
				PlayerData[i][pFactionOffer] = INVALID_PLAYER_ID;
				PlayerData[i][pFactionOffered] = -1;
			}
			if (PlayerData[i][pDraggedBy] == playerid) {
				KillTimer(PlayerData[i][pDragTimer]);

				PlayerData[i][pDragged] = 0;
				PlayerData[i][pDraggedBy] = INVALID_PLAYER_ID;
			}
			if(PlayerData[i][pMDCPlayer] == playerid) {
				PlayerData[i][pMDCPlayer] = INVALID_PLAYER_ID;
				PlayerData[i][pTrackTime] = 0;
			}
			if (PlayerData[i][pTakeItems] == playerid)
			{
				PlayerData[i][pTakeItems] = INVALID_PLAYER_ID;
			}
		}
	}

	// Reset While Take Bus sidejob
	if(IsPlayerWorkInBus(playerid)) {
		DisablePlayerRaceCheckpoint(playerid);
	}

	// Reset While Stealer
	if(PlayerData[playerid][pCarStealing]) {
		PlayerData[playerid][pCarStealingTime] = 0;
		PlayerData[playerid][pCarStealingDelay] = 120;
   		PlayerData[playerid][pCarStealing] = false;
		DisablePlayerCheckpoint(playerid);
		SendServerMessage(playerid, "The car stealing mission ~r~failed~W~ because you were disconnected", 5000);
		ResetVehicle(PlayerData[playerid][pCarStealingVehicle]);
		DestroyVehicle(PlayerData[playerid][pCarStealingVehicle]);
		PlayerData[playerid][pCarStealingVehicle] = INVALID_VEHICLE_ID;
	}

	// Save Master Account & Character
	if(PlayerData[playerid][pSpawned]) {
		SQL_SaveCharacter(playerid, 1);
		SQL_SaveAccounts(playerid);
	}

	// Other
	DestroyJobVehicle(playerid);
	DestroyPlayer3DText(playerid);
	SafeCracking_ResetPlayer(playerid, 1);
	ResetNameTags(playerid);
	ResetStatistics(playerid);

	// Killtimer
	stop PlayerData[playerid][pForagerTimer];
	stop LoginTimer[playerid];
	return 1;
}


ResetNameTags(playerid)
{
	foreach(new i : Player)
	{
		if(IsPlayerConnected(i))
		{
			if(PlayerData[i][pTogIDW])
			{
				if(NameTag[i][playerid] != PlayerText3D:-1) DeletePlayer3DTextLabel(i, NameTag[i][playerid]), NameTag[i][playerid] = PlayerText3D:-1;
			}
		}
	}
	// name tag
	if(PlayerData[playerid][pTogIDW])
	{
        foreach(new i : Player)
        {
			if(IsPlayerConnected(i))
			{
				if(NameTag[playerid][i] != PlayerText3D:-1) DeletePlayer3DTextLabel(playerid, NameTag[playerid][i]), NameTag[playerid][i] = PlayerText3D:-1;
			}
        }
        PlayerData[playerid][pTogIDW] = false;
    }
	return 1;
}


DestroyPlayer3DText(playerid)
{
    if(IsValidDynamic3DTextLabel(PlayerData[playerid][pAdoTag]))
        DestroyDynamic3DTextLabel(PlayerData[playerid][pAdoTag]);

    PlayerData[playerid][pAdoTag]       = Text3D:INVALID_STREAMER_ID;
    PlayerData[playerid][pAdoActive]    = false;
    return 1;
}

stock ResetStatistics(playerid)
{
	static const empty_player[e_player_data];
    PlayerData[playerid] = empty_player;

	static const empty_account[ucp_data];
    AccountData[playerid] = empty_account;

	static const empty_tempplayer[playerTemp];
    PlayerTemp[playerid] = empty_tempplayer;

    AccountData[playerid][pUsername][0] = EOS;
	AccountData[playerid][pUsername] = EOS;

	forex (i, MAX_CHARACTERS) {
        CharacterList[playerid][i][0] = EOS;
    }
	forex (i, MAX_OWNABLE_CARS) {
        ListedVehicles[playerid][i] = -1;
    }
	forex(i, MAX_HOUSE_FURNITURE)
	{
        ListedFurniture[playerid][i] = -1;
    }
	forex(i, MAX_OWNABLE_HOUSES)
	{
        ListedHouse[playerid][i] = -1;
    }
	forex(i, 7)
	{
		PlayerData[playerid][pDamages][i] = 100.0;
		PlayerData[playerid][pBullets][i] = 0;
	}
	forex(i, MAX_INVENTORY)
	{
	    InventoryData[playerid][i][invExists] = false;
	    InventoryData[playerid][i][invModel] = 0;
	    InventoryData[playerid][i][invQuantity] = 0;
	}
	forex(i, PLAYER_MAX_HOUSE_SHARE_KEYS)
	{
		if(HouseKeyData[playerid][i][houseKeyExists]) {
			HouseKeyData[playerid][i][houseID] = INVALID_HOUSE_KEY_ID;
			HouseKeyData[playerid][i][playerID] = INVALID_HOUSE_KEY_ID;
            HouseKeyData[playerid][i][houseOwnerID] = INVALID_HOUSE_KEY_ID;
			HouseKeyData[playerid][i][houseKeyExists] = 0;
		}
	}
	forex(i, 14)
	{
		ModQueue[playerid][i] = 0;
	}
	forex(i, MAX_CLOTHES)
	{
		cl_dataslot[playerid][i] = -1;
		ClothingData[playerid][i][cl_object] = 0;
	}
	forex(x, MAX_PHONECONTACTS)
	{
		PhoneContacts[playerid][x][ContactName][0] = EOS;
		PhoneContacts[playerid][x][ContactNumber] = 0;
		PhoneContacts[playerid][x][cID] = 0;
	}
	forex(i, MAX_PLAYER_INVOICES)
	{
	    InvoiceData[playerid][i][invoiceID] = 0;
		InvoiceData[playerid][i][invoiceExists] = false;
		InvoiceData[playerid][i][invoiceFee] = 0;
	}

	forex(i, 13)
    {
        PlayerData[playerid][pGuns][i] = 0;
        PlayerData[playerid][pAmmo][i] = 0;
	}
	forex(ai, MAX_WAREHOUSE_STORAGE)
	{
		WareHouse[playerid][ai][cItemExists] = false;
		WareHouse[playerid][ai][cItemModel] = 0;
		WareHouse[playerid][ai][cItemQuantity] = 0;
	}
	forex(i, 34)
	{
		WeaponSettings[playerid][i][Position][0] = -0.116;
		WeaponSettings[playerid][i][Position][1] = 0.189;
		WeaponSettings[playerid][i][Position][2] = 0.088;
		WeaponSettings[playerid][i][Position][3] = 0.0;
		WeaponSettings[playerid][i][Position][4] = 44.5;
		WeaponSettings[playerid][i][Position][5] = 0.0;
		WeaponSettings[playerid][i][Bone] = 1;
		WeaponSettings[playerid][i][Hidden] = false;
	}

	if (PlayerData[playerid][pEditPump] != -1)
	{
		Pump_Refresh(PlayerData[playerid][pEditPump]);
		PlayerData[playerid][pEditPump] = -1;
		PlayerData[playerid][pGasStation] = -1;
	}

	if (PlayerData[playerid][pEditAtm] != -1)
	{
		ATM_Refresh(PlayerData[playerid][pEditAtm]);
		PlayerData[playerid][pEditAtm] = -1;
	}
	if(IsValidDynamic3DTextLabel(PlayerData[playerid][pAdoTag]))
        DestroyDynamic3DTextLabel(PlayerData[playerid][pAdoTag]);

	reportDelay[playerid] = 0;
	askDelay[playerid] = 0;
	isplayerMinining[playerid] = false;
	PlayerData[playerid][pAdoTag] = Text3D:INVALID_STREAMER_ID;
	PlayerData[playerid][pEditPump] = -1;
	PlayerData[playerid][pGasStation] = -1;
	PlayerData[playerid][pEditAtm] = -1;
	PlayerData[playerid][pName] = EOS;
    PlayerData[playerid][pAdoActive] = false;
	PlayerData[playerid][pTaxiCalled] = 0;
	PlayerData[playerid][pID] = -1;
	PlayerData[playerid][pSpawned] = false;
    PlayerData[playerid][pInjuredTime] = 1200;
    PlayerData[playerid][pInjured] = false;
	PlayerData[playerid][pDead] = false;
    PlayerData[playerid][pGender] = 1;
	PlayerData[playerid][pWarehouse] = 0;
	PlayerData[playerid][pTables] = 0;
	PlayerData[playerid][pWarehouseTime] = 0;
    PlayerData[playerid][pBank] = 0;
    PlayerData[playerid][pScore] = 1;
	PlayerData[playerid][pSalary] = 0;
    PlayerData[playerid][pHealth] = 100;
    PlayerData[playerid][pArmor] = 0;
	PlayerData[playerid][pHunger] = 100;
	PlayerData[playerid][pThirst] = 100;
	PlayerData[playerid][pStress] = 0;
	PlayerData[playerid][pExecute] = 0;
	PlayerData[playerid][pListitem] = -1;
	PlayerData[playerid][pInventoryItem] = -1;
	PlayerData[playerid][pInventory] = false;
	PlayerData[playerid][pEntrance] = -1;
	PlayerData[playerid][pFreeze] = 0;
	PlayerData[playerid][pPressBtn] = false;
	PlayerData[playerid][pMaskID] = random(90000) + 10000;
	PlayerData[playerid][pBusiness] = -1;
	PlayerData[playerid][pHouse] = -1;
	PlayerData[playerid][pBusinessSeller] = INVALID_PLAYER_ID;
	PlayerData[playerid][pBusinessOffered] = -1;
	PlayerData[playerid][pBusinessValue] = 0;
	PlayerData[playerid][pRefill] = INVALID_VEHICLE_ID;
	PlayerData[playerid][pRefillPrice] = 0;
	PlayerData[playerid][pGasPump] = -1;
	PlayerData[playerid][pGasStation] = -1;
	PlayerData[playerid][pProductModify] = 0;
	PlayerData[playerid][pSkinPrice] = 0;
	PlayerData[playerid][pTempModel] = -1;
	PlayerData[playerid][pHouseSeller] = INVALID_PLAYER_ID;
	PlayerData[playerid][pHouseOffered] = -1;
	PlayerData[playerid][pHouseValue] = 0;
	PlayerData[playerid][pGarageSeller] = INVALID_PLAYER_ID;
	PlayerData[playerid][pGarageOffered] = -1;
	PlayerData[playerid][pGarageValue] = 0;
	PlayerData[playerid][pStorageItem] = 0;
	PlayerData[playerid][pSelectedSlot] = -1;
	PlayerData[playerid][pOnDuty ] = 0;
	PlayerData[playerid][pAFK] = 0;
	PlayerData[playerid][pEating] = -1;
	PlayerData[playerid][pEatingCount] = 0;
	PlayerData[playerid][pJetpack] = 0;
	PlayerData[playerid][pClothing] = 0;
	PlayerData[playerid][pNumber] = -1;
	PlayerData[playerid][pExp] = 0;
	PlayerData[playerid][pIncomingCall] = 0;
	PlayerData[playerid][pCallLine] = INVALID_PLAYER_ID;
	PlayerData[playerid][pCallTime] = 0;
	PlayerData[playerid][pCuffed] = false;
	PlayerData[playerid][pTied] = 0;
	PlayerData[playerid][pTazed] = false;
	PlayerData[playerid][pTazer] = false;
	PlayerData[playerid][pArrest] = false;
	PlayerData[playerid][pJailTime] = 0;
	PlayerData[playerid][pRefilling] = 0;
	PlayerData[playerid][pSpectator] = INVALID_PLAYER_ID;
	PlayerData[playerid][pSpraying] = false;
	PlayerData[playerid][pColoring] = 0;
	PlayerData[playerid][pVehicle] = -1;
	PlayerData[playerid][pColor1] = 0;
	PlayerData[playerid][pColor2] = 0;
	PlayerData[playerid][pTaxiPlayer] = INVALID_PLAYER_ID;
	PlayerData[playerid][pMechPrice][0] = 0;
	PlayerData[playerid][pMechPrice][1] = 0;
	PlayerData[playerid][pVoiceMode] = 1;
	PlayerData[playerid][pWaktuRob] = -1;
	PlayerData[playerid][pOnDuty] = false;
	PlayerData[playerid][pFactionID] = -1;
	PlayerData[playerid][pFactionRank] = 0;
	PlayerData[playerid][pSelectedSlot] = -1;
	PlayerData[playerid][pEditFurniture] = -1;
	PlayerData[playerid][pFaction] = -1;
	PlayerData[playerid][pReportPoint] = 0;
	PlayerData[playerid][pAskPoint] = 0;
	PlayerData[playerid][pTargetid] = -1;
	PlayerData[playerid][pTakeTransport] = -1;
	PlayerData[playerid][pDragged] = 0;
    PlayerData[playerid][pDraggedBy] = INVALID_PLAYER_ID;
	PlayerData[playerid][pMDCPlayer] = INVALID_PLAYER_ID;
	PlayerData[playerid][pCar] = -1;
	PlayerData[playerid][pSpeedTime] = 0;
	PlayerData[playerid][pFrequency] = 0;
	PlayerData[playerid][pHoldWeapon] = 0;
	PlayerData[playerid][pUsedMagazine] = 0;
	PlayerData[playerid][pPhoneOff] = 0;
	PlayerData[playerid][pFriskOffer] = INVALID_PLAYER_ID;
	PlayerData[playerid][pFrisk] = false;
	PlayerData[playerid][pRekening] = -1;
	PlayerData[playerid][pFactionOffer] = INVALID_PLAYER_ID;
	PlayerData[playerid][pFactionOffered] = -1;
	PlayerData[playerid][pBPJS] = 0;
	PlayerData[playerid][pBPJSTime] = 0;
	PlayerData[playerid][pFlat] = -1;
    PlayerData[playerid][pTargetVehicle] = -1;
	PlayerData[playerid][pODL] = false;
	PlayerData[playerid][pCarSeller] = INVALID_PLAYER_ID;
	PlayerData[playerid][pCarOffered] = -1;
	PlayerData[playerid][pCarValue] = 0;
	PlayerData[playerid][pJobVehicle] = 0;
	PlayerData[playerid][pLoopAnim] = false;
	PlayerData[playerid][pActivityTime] = -1;
	PlayerData[playerid][pDrugTime] = 0;
	PlayerData[playerid][pDrugUsed] = 0;
	SellLastSpawn[playerid] = -1;
	PlayerData[playerid][pHudMode] = 0;
	PlayerData[playerid][pWeapon] = 0;
	PlayerData[playerid][pSkin] = 100;
	PlayerData[playerid][pKiller] = INVALID_PLAYER_ID;
	PlayerData[playerid][pCreatedAccount] = false;
	PlayerData[playerid][pVIP] = 0;
	PlayerData[playerid][pVIPTime] = 0;
	PlayerData[playerid][pGold] = 0;
	PlayerData[playerid][pChangePhone] = 0;
	PlayerData[playerid][pTakeItems] = INVALID_PLAYER_ID;
	PlayerData[playerid][pHarvest] = -1;
	PlayerData[playerid][pLastVehicle] = 0;
	PlayerData[playerid][pLastCar] = INVALID_VEHICLE_ID;
	PlayerData[playerid][pActivity] = -1;
	PlayerData[playerid][pStarterpack] = 0;
	PlayerData[playerid][pOnPhone] = false;
	PlayerData[playerid][pBoombox] = INVALID_PLAYER_ID;
	PlayerData[playerid][pFightStyle] = 0;
	PlayerData[playerid][pEditObject] = -1;

	PlayerData[playerid][pSweeperLevel] = 1;
	PlayerData[playerid][pFishingLevel] = 1;
	PlayerData[playerid][pTrashmasterLevel] = 1;
	PlayerData[playerid][pMissionsLevel] = 1;
	PlayerData[playerid][pBusLevel] = 1;
	PlayerData[playerid][pTaxiCalled] = 0;
	PlayerData[playerid][pCivilianTime] = 0;

	if(IsValidObject(PlayerData[playerid][pSkate])) DestroyObject(PlayerData[playerid][pSkate]);

	SendTENCODE[playerid] = false;

	PhonePage[playerid] = PHONE_OFF;

	//Seatbelt{playerid} = 0;
    Helmet[playerid] = 0;
	EditClothing{playerid} = false;
	BuyClothing{playerid} = false;
	ToggleNavbar[playerid] = true;
	EditWeedPlant[playerid] = -1;
	PlayerSelectedCharacter{playerid} = false;

	ResetFaction(playerid);

    WeaponTick[playerid] = 0;
	EditingWeapon[playerid] = 0;

	BoomboxData[playerid][boomboxPlaced] = 0;
    BoomboxData[playerid][boomboxPos][0] = 0.0;
    BoomboxData[playerid][boomboxPos][1] = 0.0;
    BoomboxData[playerid][boomboxPos][2] = 0.0;

	ToggleRadio[playerid] = 0;

	HoldWeapon(playerid, 0);
	ResetCuttingTree(playerid);
	SetHealth(playerid, 100);

	foreach(new i : Player)
    {
		NameTag[playerid][i] = PlayerText3D:-1;
    }

	Emergency_Clear(playerid);
	HidePlayerFooter(playerid);
	Loading_Remove(playerid);
	Damage_Reset(playerid);

    printf("Resetting player statistics for ID %d", playerid);
	return 1;
}

ViewCharges(playerid, name[])
{
    new
        string[128];

    format(string, sizeof(string), "SELECT * FROM `warrants` WHERE `Suspect` = '%s' ORDER BY `ID` DESC", SQL_ReturnEscaped(name));
    mysql_tquery(g_SQL, string, "OnViewCharges", "ds", playerid, name);
    return 1;
}

/*task RamadhanTeks[300000]()
{
	va_SendClientMessageToAll(X11_LIMEGREEN,"[Ramadhan 1445 H] "WHITE"Selamat Menunaikan Ibadah Puasa 1445 H"); 
}*/

AddWarrant(targetid, playerid, description[])
{
    new
        string[255];

    format(string, sizeof(string), "INSERT INTO `warrants` (`Suspect`, `Username`, `Date`, `Description`) VALUES('%s', '%s', '%s', '%s')", ReturnName(targetid), ReturnName(playerid), ReturnDate(), SQL_ReturnEscaped(description));
    mysql_tquery(g_SQL, string);
}

Function:OfflinePI(playerid, name[])
{
    if(!cache_num_rows()) return SendErrorMessage(playerid, "Invalid!."), MDCPanel(playerid);

    new str[1024],
        query[128],
		id,
		job,
		number,
        Cache: warrans,
		Cache: arrest,
        Cache: charges;

    cache_get_value_name_int(0, "pID", id);
	cache_get_value_name_int(0, "Number", number);
	cache_get_value_name_int(0, "Job", job);

    strcat(str, sprintf("{AAC4E5}I. Personal information\n"WHITE"Personal ID: "YELLOW"SA%09d\n"WHITE"Name: "YELLOW"%s\n", id, name));
    strcat(str, sprintf(""WHITE"Phone Number: "YELLOW"%d\n"WHITE"Job: "YELLOW"%s\n\n", number, Job_ReturnName(job)));
    strcat(str, "\n{AAC4E5}II. Active Charges\n"WHITE"");
    mysql_format(g_SQL, query, sizeof(query), "SELECT * FROM `warrants` WHERE `Suspect` = '%s' ORDER BY `ID` DESC", name);
    charges = mysql_query(g_SQL, query);

    if(!cache_num_rows())
        strcat(str, "None\n");

    for(new i=0; i<cache_num_rows(); i++) {
        new reason[128],date[64], suspect[24], username[24];
        cache_get_value_name(i, "Suspect", suspect);
        cache_get_value_name(i, "Description", reason);
        cache_get_value_name(i, "Date", date);
        cache_get_value_name(i, "Username", username);

        strcat(str, sprintf("%d. {BDF38B}%s\n"WHITE"Issuer: "YELLOW"%s"WHITE" - (%s)\n", i+1, reason, username, date));
    }
    cache_delete(charges);

    strcat(str, "\n{AAC4E5}III. Registered Vehicle"WHITE"\n");

    mysql_format(g_SQL, query, sizeof(query), "SELECT * FROM `vehicle` WHERE `Owner` = '%d' ORDER BY `ID` DESC LIMIT 3", id);
    warrans = mysql_query(g_SQL, query);

    if(!cache_num_rows())
        strcat(str, "None\n");

    for(new i=0; i<cache_num_rows(); i++) {
        new plate[24], model;

		cache_get_value_name_int(i, "Model", model);
        cache_get_value_name(i, "Plate", plate);

        strcat(str, sprintf(""YELLOW"%s "WHITE"( %s )\n", GetVehicleNameEx(model), plate));
    }
    cache_delete(warrans);

	strcat(str, "\n{AAC4E5}IV. Arrest Record"WHITE"\n");
	new fine, reason[37], date[40];
	mysql_format(g_SQL, query, sizeof(query), "SELECT * FROM arrest WHERE owner = '%d' ORDER BY id ASC", id);
	arrest =  mysql_query(g_SQL, query);

	if(!cache_num_rows())
        strcat(str, "None\n");

	for(new i=0; i<cache_num_rows(); i++)
	{
		cache_get_value_name_int(i, "fine", fine);
		cache_get_value_name(i, "date", date);
		cache_get_value_name(i, "reason", reason);

		strcat(str, sprintf(""WHITE"%d. {BDF38B}%s"WHITE"\n", i+1, reason));
	}
	cache_delete(arrest);

    Dialog_Show(playerid, ShowOnly, DIALOG_STYLE_MSGBOX, ""WHITE""SERVER_NAME" "SERVER_LOGO" Summary", str, "Close", "");
    return 1;
}

stock MDCPanel(playerid)
{
	new
    vehicleid = GetPlayerVehicleID(playerid),
    id = -1;
    {
        if(GetFactionType(playerid) != FACTION_POLICE) return SendErrorMessage(playerid, "Kamu bukan polisi.");
        if((id = Vehicle_GetID(vehicleid)) != -1 && VehicleData[id][cFaction] == -1) return SendErrorMessage(playerid, "Kamu harus berada di kendaraan faksi!");
        if(!PlayerData[playerid][pOnDuty]) return SendErrorMessage(playerid, "Kamu harus bertugas terlebih dahulu.");
        if(IsABike(GetPlayerVehicleID(playerid)) || !IsEngineVehicle(GetPlayerVehicleID(playerid))) return SendErrorMessage(playerid, "Kamu tidak dalam kendaraan.");
    }

    Dialog_Show(playerid, MainMDC, DIALOG_STYLE_LIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Mobile Data Computer", "Active Warrants\nPlace Charges\nView Charges\nPersonal Identification\nOffline Personal Identification", "Select", "Cancel");
	return 1;
}
YCMD:mdc(playerid, params[], help)
{
    MDCPanel(playerid);
    return 1;
}

YCMD:trace(playerid, params[], help)
{
    if(GetFactionType(playerid) != FACTION_POLICE)
        return SendErrorMessage(playerid, "Kamu bukan polisi.");

    if(!PlayerData[playerid][pOnDuty])
        return SendErrorMessage(playerid, "Kamu bukan tugas faksi.");

    if(IsABike(GetPlayerVehicleID(playerid)) || !IsEngineVehicle(GetPlayerVehicleID(playerid))) 
        return SendErrorMessage(playerid, "Kamu tidak dalam kendaraan.");

    Dialog_Show(playerid, Trace, DIALOG_STYLE_LIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Trace", "Vehicle number plate\nPhone Number", "Select", "Cancel");
    return 1;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
    #if defined DEBUG_MODE
	    printf("[debug] OnPlayerEnterVehicle(PID : %d VID : %d ISPASSENGER : %d)", playerid, vehicleid, ispassenger);
	#endif

	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(GetVehicleDriver(vehicleid) != INVALID_VEHICLE_ID && ispassenger == 0)
	{
		static
	    Float:x,
	    Float:y,
	    Float:z;

		GetPlayerPos(playerid, x, y, z);
		SetPlayerPos(playerid, x, y, z + 5);

		GameTextForPlayer(playerid, "Car Jacking", 5000, 4);
		PlayerPlaySound(playerid, 1130, 0.0, 0.0, 0.0);
		return 1;
	}

	PlayerData[playerid][pLastCar] = GetPlayerVehicleID(playerid);

    if(GetPlayerSpecialAction(playerid) == SPECIAL_ACTION_CUFFED || GetPlayerSpecialAction(playerid) == SPECIAL_ACTION_CARRY || PlayerData[playerid][pInjured]) {
        ClearAnimations(playerid);
        return 0;
    }
	if(PlayerData[playerid][pJobVehicle] != 0)
	{
		if(vehicleid == JobVehicle[PlayerData[playerid][pJobVehicle]][Vehicle])
		{
			SetVehicleParamsForPlayer(JobVehicle[PlayerData[playerid][pJobVehicle]][Vehicle], playerid, 1, 0);
			ShowPlayerFooter(playerid, sprintf("~W~Masuk ke kendaraan ~b~%s", Job_ReturnName(PlayerData[playerid][pJob])), 3000);
		}
	}

	CheckPlayerRentalExpired(playerid);
    
	if(GetFactionType(playerid) == FACTION_POLICE && PlayerData[playerid][pOnDuty])
    {
        if(IsPlayerInFactionGarageVehicle(playerid))
        {
            PlayerData[playerid][pMegaphone] = true;
            ShowMegaphoneTextdraw(playerid);
            SendServerMessage(playerid, "Megaphone aktif otomatis karena kamu masuk kendaraan fraksi.");
        }
    }

	//megaphone
	// Aktifkan kembali TextDraw megaphone jika player polisi masuk kendaraan
	if(PlayerData[playerid][pFaction] == FACTION_POLICE && PlayerData[playerid][pOnDuty])
	{
		if(PlayerData[playerid][pMegaphone])
		{
			ShowMegaphoneTextdraw(playerid);
			SendServerMessage(playerid, "Megaphone aktif kembali.");
		}
	}

	return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;
	///megaphone
	PlayerData[playerid][pMegaphone] = false;
    HideMegaphoneTextdraw(playerid);
    SendServerMessage(playerid, "Megaphone nonaktif karena kamu keluar dari kendaraan.");
	
	if(PlayerData[playerid][pMegaphone])
    {
        DisableMegaphone(playerid);
        SendServerMessage(playerid, "Megaphone nonaktif karena kamu keluar dari kendaraan.");
    }
	return 1;
}

public OnVehicleDamageStatusUpdate(vehicleid, playerid)
{
	new panel, doors, lights, tires, Float: HP, Float:fHealth;
	GetVehicleHealth(vehicleid, fHealth);

	foreach(new i : PlayerVehicle)
    {
        if(vehicleid == VehicleData[i][cVehicle])
		{
		    if(VehicleData[i][cUpgrade][0] == 1)
		    {
			    GetVehicleHealth(VehicleData[i][cVehicle], HP);
			    if(HP >= 1300)
			    {
				    GetVehicleDamageStatus(vehicleid, panel, doors, lights, tires);
			        UpdateVehicleDamageStatus(vehicleid, 0, 0, 0, tires);
				}
				else
				{
				    GetVehicleDamageStatus(vehicleid, panel, doors, lights, tires);
				    UpdateVehicleDamageStatus(vehicleid, panel, doors, lights, tires);
			  	}
			}
			break;
		}
	}
	return 1;
}

public Streamer_OnPluginError(const error[]) {
	printf("[STREAMER ERROR] %s", error);
	return 1;
}

public OnVehicleStreamOut(vehicleid, forplayerid)
{
	return 1;
}
public OnVehicleStreamIn(vehicleid, forplayerid)
{
	return 1;
}

public e_COMMAND_ERRORS:OnPlayerCommandReceived(playerid, cmdtext[], e_COMMAND_ERRORS:success)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

    if(success != COMMAND_OK) {
        SendErrorMessage(playerid, "The command %s is unknown, check /help to see the list of available commands", cmdtext);
        return COMMAND_OK;
    }
	if(PlayerData[playerid][pID] == -1)
	{
		SendServerMessage(playerid, "You must log in first before using the command.");
		return COMMAND_DENIED;
	}
    return COMMAND_OK;
}

public OnPlayerSpawn(playerid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(!LewatConnect[playerid])
		return Kick(playerid);

	if(!LewatClass[playerid])
		return Kick(playerid);

	if(SelectCharIndex[playerid] != -1)
	{
		Player_ToggleTelportAntiCheat(playerid, false);
		TogglePlayerSpectating(playerid, false);
		SetPlayerCameraPos(playerid,2402.485351,1596.094604,31.153108);
		SetPlayerCameraLookAt(playerid,2407.114746,1591.432861,30.413135);
		SetPlayerInterior(playerid, -1);
		SetPlayerVirtualWorld(playerid, 1000 + playerid); 
		ApplyAnimation(playerid, "ped", "SEAT_down", 4.1, 0, 0, 0, 1, 0);
		return 1;
	}
	if(!PlayerData[playerid][pSpawned] && GetPVarInt(playerid, "IsAtEvent") == 0)
	{
		//if(IsPlayerUsingAndroid(playerid))
			///defer OnAutoAimCheck[2000](playerid);

	    PlayerData[playerid][pSpawned] = true;
	    if (PlayerData[playerid][pHealth] <= 0.0)
		{
			PlayerData[playerid][pHealth] = 100.0;
			printf("[DEBUG] Health kosong, fallback ke 100 untuk player %d", playerid);
		}
		SetPlayerHealth(playerid, PlayerData[playerid][pHealth]);
		//SetPlayerHealth(playerid, PlayerData[playerid][pHealth]);
	    SetPlayerArmour(playerid, PlayerData[playerid][pArmor]);
	    SetPlayerVirtualWorld(playerid, PlayerData[playerid][pWorld]);
		SetPlayerInterior(playerid, PlayerData[playerid][pInterior]);

		Streamer_ToggleIdleUpdate(playerid, true);
		Streamer_ToggleItemUpdate(playerid, STREAMER_TYPE_OBJECT, true);

		FreezePlayer(playerid, 3000);

		SetValidColor(playerid);

		new str[40];
		format(str, sizeof(str), "~w~Welcome Back~n~~p~   %s", ReturnName(playerid));
		ShowPlayerFooter(playerid, str, 5000, "SAFE SPAWN");


		// foreach(new i : Player)
        // {
		// 	if(PlayerData[i][pTogLogin] == 0 && PlayerData[i][pSpawned] && playerid != i)
        //     {
        //         new country[24], city[24];
        //         GetPlayerCountry(playerid, country, sizeof(country));
        //         GetPlayerCity(playerid, city, sizeof(city));

        //         va_SendClientMessage(i, X11_GRAY,"** %s[%d] telah terkoneksi ke dalam server %s.",ReturnName(playerid,1), playerid, !strcmp(country, "Unknown", true) ? ("") : sprintf("(%s, %s)", city, country));
        //     }
        // }
		va_SendClientMessage(playerid, X11_SKYBLUE, "SERVER: {FFFFFF}Welcome back, {00FFFF}%s!", ReturnName(playerid));
		va_SendClientMessage(playerid, X11_SKYBLUE, "SERVER: {FFFFFF}Today is {FFFF00}%s", ConvertTimestamp(Timestamp:Now()));
		va_SendClientMessage(playerid, X11_SKYBLUE, "SERVER: {FFFFFF}Selamat berRP dan mulailah petualangan Anda hari ini!");
		va_SendClientMessage(playerid, X11_SKYBLUE, "SERVER: {FFFFFF}Ketik {FFFF00}'/ask' {FFFFFF}jika anda memiliki pertanyaan dan {FFFF00}'/report' {FFFFFF}untuk melaporkan player atau bug.");
		va_SendClientMessage(playerid, X11_SKYBLUE, "SERVER: {FFFFFF}Pastikan Anda telah membaca {FF8C00}#rules-server {FFFFFF}dalam discord sebelum memulai permainan.");
		va_SendClientMessage(playerid, X11_SKYBLUE, "SERVER: {FFFFFF}ketik {FFFF00}'/sid' {FFFFFF}jika ingin melihat nama player sekitar anda.");

		//if(IsPlayerUsingOfficialClient(playerid)) va_SendClientMessage(playerid, X11_SKYBLUE, "</> {FFFFFF}Kamu tedeteksi menggunakaan client "GREEN"official"WHITE" SAMP/OpenMP.");
		//else va_SendClientMessage(playerid, X11_SKYBLUE, "</> {FFFFFF}Kamu tedeteksi menggunakaan client "RED"ilegal"WHITE" gunakan client dibawah."), va_SendClientMessage(playerid, X11_SKYBLUE, "</> OpenMP: {FFFF00}https://www.open.mp/"), va_SendClientMessage(playerid, X11_SKYBLUE, "</> SAMP: {FFFF00}https://www.sa-mp.mp/");

		SetTimerEx("SpawnTimer", 1000, false, "d", playerid);


		if(PlayerData[playerid][pPos][0] == 0.0 && PlayerData[playerid][pPos][1] == 0.0 && PlayerData[playerid][pPos][2] == 0.0) {

			SetPlayerPos(playerid, 1646.6320,-2286.4814,-1.2095);
			SetPlayerFacingAngle(playerid, 269.1223);
			SendCustomMessage(playerid, "Info", "Spawn Anda dipindahkan karena ada kesalahan yang memuat posisi terakhir.");
			SetHealth(playerid, 100);
		}
		va_SendClientMessage(playerid, X11_SKYBLUE, "");
	}
	if(PlayerData[playerid][pJailTime] > 0 && GetPVarInt(playerid, "IsAtEvent") == 0)
	{
	    if (PlayerData[playerid][pArrest])
	        SetPlayerArrest(playerid);
	    else
	    {
		    SetPlayerPos(playerid, 197.6346, 175.3765, 1003.0234);

		    SetPlayerInterior(playerid, 3);

		    SetPlayerVirtualWorld(playerid, (playerid + 100));
		    SetPlayerFacingAngle(playerid, 0.0);
		    SetCameraBehindPlayer(playerid);
		}
	    SendCustomMessage(playerid, "Info", "Kamu memiliki "YELLOW"%d detik"WHITE" waktu penjara yang tersisa.", PlayerData[playerid][pJailTime]);

		//Aksesoris_Sync(playerid);
	}
    else
	{
		if(PlayerData[playerid][pDead] && GetPVarInt(playerid, "IsAtEvent") == 0)
		{
			PlayerData[playerid][pInjured] = false;
			PlayerData[playerid][pDead] = false;

			SetPlayerInterior(playerid, 0);
			SetPlayerVirtualWorld(playerid, 0);
			Streamer_Update(playerid, STREAMER_TYPE_OBJECT);

			SetHealth(playerid, 100);
			SetPlayerPos(playerid, 1236.6245,-1569.4077,13.3828);
			SetPlayerFacingAngle(playerid, 179.2990);
			SetCameraBehindPlayer(playerid);
			ResetWeapons(playerid);
			TogglePlayerControllable(playerid, true);

			SendCustomMessage(playerid, "Hospital", "Kamu telah dihidupkan kembali di rumah sakit "YELLOW"Los Santos "WHITE"dan dikenakan biaya $500");
			GiveMoney(playerid, -500, "Bayar hospital");
			LogPlayerTransaction(playerid, "Hospital", INVALID_PLAYER_ID, 500);
			ResetPlayerDamages(playerid);

			Damage_Reset(playerid);

			//Aksesoris_Sync(playerid);

			// RemoveDrag(playerid);

			// DragCheck(playerid);
		}
		else if (!PlayerData[playerid][pDead] && GetPVarInt(playerid, "IsAtEvent") == 0)
		{
			SetValidColor(playerid);
			SetPlayerVirtualWorld(playerid, PlayerData[playerid][pWorld]);
			SetPlayerInterior(playerid, PlayerData[playerid][pInterior]);
			SetWeapons(playerid);

			SetPlayerArmedWeapon(playerid, WEAPON_FIST);

			if(PlayerData[playerid][pInjured] && PlayerData[playerid][pJailTime] < 1)
			{
				SetPlayerPos(playerid, PlayerData[playerid][pPos][0], PlayerData[playerid][pPos][1], PlayerData[playerid][pPos][2]);
				ApplyAnimation(playerid, "WUZI", "CS_DEAD_GUY", 4.1, false, false, false, true, 0, true);
				PlayerData[playerid][pInjured] = true;
				SetHealth(playerid, 100);
				PlayerData[playerid][pInjuredTime] = 300;
				SQL_SaveCharacter(playerid);
			}

			if(PlayerData[playerid][pAdminDuty] && !PlayerData[playerid][pAhide])
				SetPlayerColor(playerid, 0xFF0000FF);
			
			//Aksesoris_Sync(playerid);

			if (PlayerData[playerid][pScore] == 1)
			{
				PlayerData[playerid][newCitizen] = true;
				PlayerData[playerid][newCitizenTimer] = 3600;
				for (new i = 0; i < 6; i++)
				{
					PlayerTextDrawShow(playerid, UI_Segel[playerid][i]);

				}
				ShowSegel(playerid);
			}

			if (PlayerData[playerid][newCitizen] && PlayerData[playerid][newCitizenTimer] > 0)
			{
				for (new i = 0; i < 6; i++)
				{
					PlayerTextDrawShow(playerid, UI_Segel[playerid][i]);
				}
			}
			if (PlayerData[playerid][pScore] >= 5)
			{
				for (new i = 0; i < 6; i++) PlayerTextDrawHide(playerid, UI_Segel[playerid][i]);
			}
			if (PlayerData[playerid][pScore] == 1 && !PlayerData[playerid][SegelShown])
			{
				InitSegelTextDraw(playerid);
				for (new i = 0; i < 6; i++) PlayerTextDrawShow(playerid, UI_Segel[playerid][i]);
				PlayerData[playerid][SegelShown] = true;
			}

			if (PlayerData[playerid][pScore] >= 5 && PlayerData[playerid][SegelShown])
			{
				for (new i = 0; i < 6; i++) PlayerTextDrawHide(playerid, UI_Segel[playerid][i]);
				PlayerData[playerid][SegelShown] = false;
			}

		}
	}

	return 1;
}

public OnPlayerShootRightLeg(playerid, targetid, Float:amount, weaponid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if (GetPVarInt(targetid, "IsAtEvent") > 0)
		return 1;

	if(weaponid >= 22 && weaponid <= 38) {
		PlayerData[targetid][pBullets][5]++;
		if(PlayerData[targetid][pDamages][5] > 0)
		{
			PlayerData[targetid][pDamages][5] -= amount;
			if(PlayerData[targetid][pDamages][5] <= 0)
			{
				PlayerData[targetid][pDamages][5] = 0.0;
			}
		}
	}
    return 1;
}

public OnPlayerShootLeftLeg(playerid, targetid, Float:amount, weaponid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if (GetPVarInt(targetid, "IsAtEvent") > 0)
		return 1;

	if(weaponid >= 22 && weaponid <= 38) {
		PlayerData[targetid][pBullets][6]++;
		if(PlayerData[targetid][pDamages][6] > 0)
		{
			PlayerData[targetid][pDamages][6] -= amount;
			if(PlayerData[targetid][pDamages][6] <= 0)
			{
				PlayerData[targetid][pDamages][6] = 0;
			}
		}
	}
    return 1;
}
public OnPlayerShootHead(playerid, targetid, Float:amount, weaponid)
{
 	if(IsPlayerNPC(playerid))
        return 1;

 	if(!IsPlayerConnected(playerid))
 		return 1;

 	if (GetPVarInt(targetid, "IsAtEvent") > 0)
 		return 1;

 	if(weaponid >= 22 && weaponid <= 38) {
 		PlayerData[targetid][pBullets][0]++;
 		//SetTimerEx("HidePlayerBox", 500, false, "dd", targetid, _:ShowPlayerBox(targetid, 0xFF000066));
 		if(PlayerData[targetid][pDamages][0] > 0)
 		{
 			PlayerData[targetid][pDamages][0] -= amount;
 			if(PlayerData[targetid][pDamages][0] <= 0)
 			{
 				PlayerData[targetid][pDamages][0] = 0;
 			}
 		}
 	}
    return 1;
}
public OnPlayerShootGroin(playerid, targetid, Float:amount, weaponid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if (GetPVarInt(targetid, "IsAtEvent") > 0)
		return 1;

	if(weaponid >= 22 && weaponid <= 38) {
		PlayerData[targetid][pBullets][3]++;
		if(PlayerData[targetid][pDamages][4] > 0)
		{
			PlayerData[targetid][pDamages][4] -= amount;
			if(PlayerData[targetid][pDamages][4] <= 0)
			{
				PlayerData[targetid][pDamages][4] = 0;
			}
		}
	}
    return 1;
}
public OnPlayerShootTorso(playerid, targetid, Float:amount, weaponid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if (GetPVarInt(targetid, "IsAtEvent") > 0)
		return 1;

	if(weaponid >= 22 && weaponid <= 38) {
		PlayerData[targetid][pBullets][1]++;
		if(PlayerData[targetid][pDamages][1] > 0)
		{
			PlayerData[targetid][pDamages][1] -= amount;
			if(PlayerData[targetid][pDamages][1] <= 0)
			{
				PlayerData[targetid][pDamages][1] = 0;
			}
		}
	}
    return 1;
}

public OnPlayerShootLeftArm(playerid, targetid, Float:amount, weaponid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if (GetPVarInt(targetid, "IsAtEvent") > 0)
		return 1;

	if(weaponid >= 22 && weaponid <= 38) {
		PlayerData[targetid][pBullets][3]++;
		if(PlayerData[targetid][pDamages][3] > 0)
		{
			PlayerData[targetid][pDamages][3] -= amount;
			if(PlayerData[targetid][pDamages][3] < 0)
			{
				PlayerData[targetid][pDamages][3] = 0;
			}
		}
	}
    return 1;
}

public OnPlayerShootRightArm(playerid, targetid, Float:amount, weaponid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if (GetPVarInt(targetid, "IsAtEvent") > 0)
		return 1;

	if(weaponid >= 22 && weaponid <= 38) {
		PlayerData[targetid][pBullets][2]++;
		if(PlayerData[targetid][pDamages][2] > 0)
		{
			PlayerData[targetid][pDamages][2] -= amount;
			if(PlayerData[targetid][pDamages][2] <= 0)
			{
				PlayerData[targetid][pDamages][2] = 0;
			}
		}
	}
    return 1;
}

RandomLoginScreen(playerid)
{
	TogglePlayerSpectating(playerid, true);
	SetPlayerTime(playerid, current_hour, 0);
	switch(random(6))
	{
	    case 0:
	    {
		 	SetPlayerDynamicPos(playerid, 1838.6837,-1704.9426,13.9999); // Alhambra
			InterpolateCameraPos(playerid, 1400.400878, -1737.014526, 92.646148, 1771.815063, -1741.581420, 70.703231, 9000);
			InterpolateCameraLookAt(playerid, 1405.239013, -1736.679199, 91.429573, 1775.731933, -1739.247680, 68.650878, 9000);
	    }
	    case 1:
	    {
		 	SetPlayerDynamicPos(playerid, 2255.8870,-1457.9824,18.5294); // Glen Park
			InterpolateCameraPos(playerid, 2067.357421, -1914.845458, 77.126457, 2162.559814, -1563.017700, 63.680793, 7000);
			InterpolateCameraLookAt(playerid, 2068.106201, -1909.954223, 76.408630, 2162.281738, -1558.047241, 63.214595, 7000);
	    }
	    case 2:
	    {
		 	SetPlayerDynamicPos(playerid, 1838.6837,-1704.9426,13.9999); // Idlewood
			InterpolateCameraPos(playerid, 1840.053344, -1733.400756, 60.931621, 1963.133422, -1763.364624, 77.835762, 7000);
			InterpolateCameraLookAt(playerid, 1844.712890, -1733.955444, 59.204956, 1967.605834, -1763.862426, 75.656295, 7000);
	    }
	    case 3:
	    {
		 	SetPlayerDynamicPos(playerid, 1377.2443,-776.1080,92.0957); // Mulholand
			InterpolateCameraPos(playerid, 1406.090942, -890.649230, 95.371109, 1543.376586, -897.526977, 104.968841, 7000);
			InterpolateCameraLookAt(playerid, 1406.484863, -885.718322, 94.642463, 1546.230346, -901.473266, 103.836219, 7000);
	    }
	    case 4:
	    {
		 	SetPlayerDynamicPos(playerid, 1483.5927,-1781.5214,13.5469); // Pershing Square
			InterpolateCameraPos(playerid, 1766.647705, -1799.999511, 83.710655, 1555.844116, -1599.263793, 101.893363, 9000);
			InterpolateCameraLookAt(playerid, 1762.219238, -1797.717407, 83.286163, 1552.842041, -1601.462524, 98.553779, 9000);
	    }
	    case 5:
	    {
		 	SetPlayerDynamicPos(playerid, 1377.2443,-776.1080,92.0957); // Vinewood
			InterpolateCameraPos(playerid, 1109.423706, -956.851989, 89.084526, 1323.938842, -903.115905, 113.600677, 9000);
			InterpolateCameraLookAt(playerid, 1104.463378, -957.352600, 88.703643, 1327.557739, -899.820861, 112.577796, 9000);
	    }
	}
}

SetPlayerWeaponSkill(playerid, skill)
{
	switch(skill)
	{
	    case NORMAL_SKILL:
		{
			SetPlayerSkillLevel(playerid, WEAPONSKILL_PISTOL, 0);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_PISTOL_SILENCED, 100);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_DESERT_EAGLE, 100);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_SHOTGUN, 100);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_SAWNOFF_SHOTGUN, 100);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_SPAS12_SHOTGUN, 100);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_MICRO_UZI, 0);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_MP5, 100);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_AK47, 100);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_M4, 100);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_SNIPERRIFLE, 100);
	    }
	    case MEDIUM_SKILL:
		{
			SetPlayerSkillLevel(playerid, WEAPONSKILL_PISTOL, 200);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_PISTOL_SILENCED, 500);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_DESERT_EAGLE, 200);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_SHOTGUN, 200);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_SAWNOFF_SHOTGUN, 200);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_SPAS12_SHOTGUN, 200);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_MICRO_UZI, 50);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_MP5, 250);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_AK47, 200);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_M4, 200);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_SNIPERRIFLE, 300);
	    }
	    case FULL_SKILL:
		{
			SetPlayerSkillLevel(playerid, WEAPONSKILL_PISTOL, 998);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_PISTOL_SILENCED, 999);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_DESERT_EAGLE, 999);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_SHOTGUN, 999);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_SAWNOFF_SHOTGUN, 999);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_SPAS12_SHOTGUN, 999);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_MICRO_UZI, 50);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_MP5, 999);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_AK47, 999);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_M4, 999);
			SetPlayerSkillLevel(playerid, WEAPONSKILL_SNIPERRIFLE, 999);
	    }
	}
}
// auto rp
public OnPlayerText(playerid, text[])
{
    // RP Command List
    static const rpCommands[][] = {
        "rpgun", "gunrp", "rpcrash", "crashrp", "rpfish", "rpfall", "rpmad", "rprob", "rpcj",
        "rpwar", "rpdie", "rpfixmeka", "rpcheckmeka", "rpfight", "rpcry", "rprun", "rpfear",
        "rpdropgun", "rptakegun", "rpgivegun", "rpshy", "rpnusuk", "rpharvest", "rplockhouse",
        "rplockcar", "rpnodong", "rpeat", "rpdrink"
    };

    static const rpMessages[][] = {
        "** %s lepaskan senjatanya dari sabuk dan siap untuk menembak kapan saja.",
        "** %s lepaskan senjatanya dari sabuk dan siap untuk menembak kapan saja.",
        "** %s kaget setelah kecelakaan.",
        "** %s kaget setelah kecelakaan.",
        "** %s memancing dengan kedua tangannya.",
        "** %s jatuh dan merasakan sakit.",
        "** %s merasa kesal dan ingin mengeluarkan amarah.",
        "** %s menggeledah sesuatu dan siap untuk merampok.",
        "** %s mencuri kendaraan seseorang.",
        "** %s berperang dengan sesorang.",
        "** %s pingsan dan tidak sadarkan diri.",
        "** %s memperbaiki mesin kendaraan.",
        "** %s memeriksa kondisi kendaraan.",
        "** %s ribut dan memukul seseorang.",
        "** %s sedang bersedih dan menangis.",
        "** %s berlari dan kabur.",
        "** %s merasa ketakutan.",
        "** %s meletakkan senjata kebawah.",
        "** %s mengambil senjata.",
        "** %s memberikan senjata kepada seseorang.",
        "** %s merasa malu.",
        "** %s menusuk dan membunuh seseorang.",
        "** %s memanen tanaman.",
        "** %s sedang mengunci rumah.",
        "** %s sedang mengunci kendaraan.",
        "** %s memulai menodong seseorang.",
        "** %s makan makanan yang ia beli.",
        "** %s meminum minuman yang ia beli."
    };

    // RP Command Handler
    for (new i = 0; i < sizeof(rpCommands); i++)
    {
        if (!strcmp(text, rpCommands[i], true))
        {
            new msg[128];
            format(msg, sizeof(msg), rpMessages[i], ReturnName(playerid));
            SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, msg);
            return 0;
        }
    }

    // Anti-Caps
    if (strlen(text) > 0 && GetPVarType(playerid, "Caps"))
    {
        UpperToLower(text);
    }

    // Voice Chat (@text)
    if (strlen(text) > 1 && text[0] == '@')
    {
        new lstr[128];
        format(lstr, sizeof(lstr), "%s says: %s", ReturnName(playerid), text[1]);
        ProxDetector(25.0, playerid, lstr, 0xE6E6E6E6, 0xC8C8C8C8, 0xAAAAAAAA, 0x8C8C8C8C, 0x6E6E6E6E);
        SetPlayerChatBubble(playerid, text[1], COLOR_WHITE, 10.0, 3000);
        return 0;
    }

    // Admin Duty
    if (PlayerData[playerid][pAdminDuty] == 1)
    {
        new lstr[128];
        format(lstr, sizeof(lstr), ""ORANGE"%s : "RED"(( %s ))", ReturnAdminName(playerid), text);
        ProxDetector(25.0, playerid, lstr, 0xE6E6E6E6, 0xC8C8C8C8, 0xAAAAAAAA, 0x8C8C8C8C, 0x6E6E6E6E);
        SetPlayerChatBubble(playerid, text, COLOR_WHITE, 10.0, 3000);
        return 1;
    }

    // Masked Player
    if (PlayerData[playerid][pMaskOn] == 1)
    {
        new lstr[128];
        format(lstr, sizeof(lstr), "Stranger_#%d : %s", PlayerData[playerid][pMaskID], text);
        ProxDetector(25.0, playerid, lstr, 0xE6E6E6E6, 0xC8C8C8C8, 0xAAAAAAAA, 0x8C8C8C8C, 0x6E6E6E6E);
        SetPlayerChatBubble(playerid, text, COLOR_WHITE, 10.0, 3000);
        return 1;
    }

    // Phone Call
    if (PlayerData[playerid][pCallLine] != INVALID_PLAYER_ID)
    {
        new lstr[128], pstr[128];
        format(lstr, sizeof(lstr), "[Cellphone] %s says: %s", ReturnName(playerid), text);
        ProxDetector(25.0, playerid, lstr, 0xE6E6E6E6, 0xC8C8C8C8, 0xAAAAAAAA, 0x8C8C8C8C, 0x6E6E6E6E);
        SetPlayerChatBubble(playerid, text, COLOR_WHITE, 10.0, 3000);
        format(pstr, sizeof(pstr), "[Cellphone]: {ffffff}%s.", text);
        SendClientMessage(PlayerData[playerid][pCallLine], COLOR_YELLOW, pstr);
        return 1;
    }

    // Radio
    if (PlayerData[playerid][pRadio] == 1)
    {
        new pstr[128];
        format(pstr, sizeof(pstr), "[Radio] %s: {ffffff}%s.", AccountData[playerid][pUsername], text);
        for (new i = 0; i < MAX_PLAYERS; i++)
        {
            if (IsPlayerConnected(i) && PlayerData[i][pFrequency] == PlayerData[playerid][pFrequency])
            {
                SendClientMessage(i, COLOR_YELLOW, pstr);
            }
        }
        return 1;
    }

    // Normal Chat
    new lstr[128];
    format(lstr, sizeof(lstr), "%s says: %s", ReturnName(playerid), text);
    ProxDetector(25.0, playerid, lstr, 0xE6E6E6E6, 0xC8C8C8C8, 0xAAAAAAAA, 0x8C8C8C8C, 0x6E6E6E6E);
    SetPlayerChatBubble(playerid, text, COLOR_WHITE, 10.0, 3000);

    // Megaphone
    if (PlayerData[playerid][pMegaphone])
    {
        new Float:x, Float:y, Float:z;
        GetPlayerPos(playerid, x, y, z);
        for (new i = 0; i < MAX_PLAYERS; i++)
        {
            if (i == playerid || !IsPlayerConnected(i)) continue;
            if (GetPlayerDistanceFromPoint(i, x, y, z) <= 100.0)
            {
                va_SendClientMessage(i, X11_BLUE, "[MEGAPHONE] %s: %s", PlayerData[playerid][pName], text);
            }
        }
    }

    return 1;
}

/*public OnPlayerText(playerid, text[])
{
	if(!strcmp(text, "rpgun", true) || !strcmp(text, "gunrp", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s lepaskan senjatanya dari sabuk dan siap untuk menembak kapan saja.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpcrash", true) || !strcmp(text, "crashrp", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s kaget setelah kecelakaan.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpfish", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s memancing dengan kedua tangannya.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpfall", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s jatuh dan merasakan sakit.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpmad", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s merasa kesal dan ingin mengeluarkan amarah.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rprob", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s menggeledah sesuatu dan siap untuk merampok.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpcj", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s mencuri kendaraan seseorang.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpwar", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s berperang dengan sesorang.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpdie", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s pingsan dan tidak sadarkan diri.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpfixmeka", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s memperbaiki mesin kendaraan.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpcheckmeka", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s memeriksa kondisi kendaraan.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpfight", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s ribut dan memukul seseorang.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpcry", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s sedang bersedih dan menangis.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rprun", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s berlari dan kabur.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpfear", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s merasa ketakutan.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpdropgun", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s meletakkan senjata kebawah.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rptakegun", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s mengambil senjata.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpgivegun", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s memberikan senjata kepada seseorang.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpshy", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s merasa malu.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpnusuk", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s menusuk dan membunuh seseorang.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpharvest", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s memanen tanaman.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rplockhouse", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s sedang mengunci rumah.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rplockcar", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s sedang mengunci kendaraan.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpnodong", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s memulai menodong seseorang.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpeat", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s makan makanan yang ia beli.", ReturnName(playerid));
		return 0;
	}
	if(!strcmp(text, "rpdrink", true))
	{
		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "** %s meminum minuman yang ia beli.", ReturnName(playerid));
		return 0;
	}
	if(strlen(text) > 0)
    {
        // Anti-Caps
        if(GetPVarType(playerid, "Caps"))
        {
            UpperToLower(text);
        }
		// voice chat
        if(text[0] == '@')
        {
            new lstr[1024];
            format(lstr, sizeof(lstr), "%s says: %s", ReturnName(playerid), text[1]); // Remove @ from output
            ProxDetector(25.0, playerid, lstr, 0xE6E6E6E6, 0xC8C8C8C8, 0xAAAAAAAA, 0x8C8C8C8C, 0x6E6E6E6E);
            SetPlayerChatBubble(playerid, text[1], COLOR_WHITE, 10.0, 3000);
            return 0;
        }
		else if(PlayerData[playerid][pAdminDuty] == 1)
        {
            new lstr[1024];
            format(lstr, sizeof(lstr), ""ORANGE"%s : "RED"(( %s ))", ReturnAdminName(playerid), text); // Remove @ from output
            ProxDetector(25.0, playerid, lstr, 0xE6E6E6E6, 0xC8C8C8C8, 0xAAAAAAAA, 0x8C8C8C8C, 0x6E6E6E6E);
            SetPlayerChatBubble(playerid, text, COLOR_WHITE, 10.0, 3000);
            return 1;
        }
		else if(PlayerData[playerid][pMaskOn] == 1)
        {
            new lstr[1024];
            format(lstr, sizeof(lstr), "Stranger_#%d : %s", PlayerData[playerid][pMaskID], text[1]); // Remove @ from output
            ProxDetector(25.0, playerid, lstr, 0xE6E6E6E6, 0xC8C8C8C8, 0xAAAAAAAA, 0x8C8C8C8C, 0x6E6E6E6E);
            SetPlayerChatBubble(playerid, text, COLOR_WHITE, 10.0, 3000);
            return 1;
        }
		else if(PlayerData[playerid][pCallLine] != INVALID_PLAYER_ID)
		{
			new lstr[1024], pstr[512];
            format(lstr, sizeof(lstr), "[Cellphone] %s says: %s", ReturnName(playerid), text);
            ProxDetector(25.0, playerid, lstr, 0xE6E6E6E6, 0xC8C8C8C8, 0xAAAAAAAA, 0x8C8C8C8C, 0x6E6E6E6E);
            SetPlayerChatBubble(playerid, text, COLOR_WHITE, 10.0, 3000);
			format(pstr, sizeof(pstr), "[Cellphone]: {ffffff}%s.", text);
			SendClientMessage(PlayerData[playerid][pCallLine], COLOR_YELLOW, pstr);
            return 1;
		}
		else if(PlayerData[playerid][pRadio] == 1)
		{
			new pstr[512];
			format(pstr, sizeof(pstr), "[Radio] %s: {ffffff}%s.", AccountData[playerid][pUsername], text);

			for(new i = 0; i < MAX_PLAYERS; i++)
			{
				if(IsPlayerConnected(i) && PlayerData[i][pFrequency] == PlayerData[playerid][pFrequency])
				{
					SendClientMessage(i, COLOR_YELLOW, pstr);
				}
			}
			return 1;	
		}
		else
        {
            new lstr[1024];
            format(lstr, sizeof(lstr), "%s says: %s", ReturnName(playerid), text);
            ProxDetector(25.0, playerid, lstr, 0xE6E6E6E6, 0xC8C8C8C8, 0xAAAAAAAA, 0x8C8C8C8C, 0x6E6E6E6E);
            SetPlayerChatBubble(playerid, text, COLOR_WHITE, 10.0, 3000);
            return 1;
        }
			
		//megaphone
		if(PlayerData[playerid][pMegaphone])
		{
			new Float:x, Float:y, Float:z;
			GetPlayerPos(playerid, x, y, z);
			for(new i = 0; i < MAX_PLAYERS; i++)
			{ 
				if(i == playerid || !IsPlayerConnected(i)) continue;
				new Float:tx, Float:ty, Float:tz;
				GetPlayerPos(i, tx, ty, tz);
				if(GetPlayerDistanceFromPoint(i, x, y, z) <= 100.0)
				{
					va_SendClientMessage(i, X11_BLUE, "[MEGAPHONE] %s: %s", PlayerData[playerid][pName], text);
				}
			}
			return 0;
		}
		
	}
	return 0; 
}*/

#if !defined PLAYER_STATE
	#define PLAYER_STATE: _:
#endif
public OnPlayerStateChange(playerid, PLAYER_STATE:newstate, PLAYER_STATE:oldstate)
{
	#if defined DEBUG_MODE
	    printf("[debug] OnPlayerStateChange(PID : %d NEWSTATE : %d OLDSTATE : %d)", playerid, newstate, oldstate);
	#endif

	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(IsPlayerConnected(playerid))
    {
		new vehicleid = GetPlayerVehicleID(playerid);

		if(newstate == PLAYER_STATE_DRIVER)
		{
			AbuseVehicle[playerid] = 0;

			SetPlayerArmedWeapon(playerid, WEAPON_FIST);

			new  ids = Vehicle_GetID(vehicleid);

			if(ids != -1 && VehicleData[ids][cExists])
			{
				if((VehicleData[ids][cFaction] != -1) && VehicleData[ids][cFaction] != GetFactionSQLID(playerid))
					GameTextForPlayer(playerid, "Kamu bukan bagian dari faction", 3000, 4), RemovePlayerFromVehicle(playerid);
			}

			#if defined ENABLE_VEHICLE_LABEL
			if(IsValidVehicle(vehicleid) && IsEngineVehicle(vehicleid) && !GetEngineStatus(vehicleid))
			{
				if(VehicleLabel[vehicleid] == Text3D:INVALID_STREAMER_ID) VehicleLabel[vehicleid] = CreateDynamic3DTextLabel(""WHITE"Press the [ "GREEN"n "WHITE"] button to open the vehicle radial menu", X11_WHITE, 0.0, 0.0, 0.0, 12.0, INVALID_PLAYER_ID, vehicleid, 0, -1, -1, -1, 25.0);
			}
			#endif

			if(IsPlayerInAnyVehicle(playerid))
			{
				new vehid = Vehicle_GetID(GetPlayerVehicleID(playerid));
				if(vehid != -1)
				{
					if(VehicleData[vehid][cVehicle] != INVALID_VEHICLE_ID && Vehicle_CanSpawn(vehid))
					{
						if(GetPlayerVehicleID(playerid) == VehicleData[vehid][cVehicle])
						{
							if(VehicleData[vehid][cLocked]) return RemovePlayerFromVehicle(playerid), GameTextForPlayer(playerid, "This vehicle is locked!", 3000, 4);
						}
					}
				}
			}
			if(CrackingSafeID[playerid] != -1)
			{
				SafeCracking_ResetPlayer(playerid);
			}

			if (!IsEngineVehicle(GetPlayerVehicleID(playerid)))
			{
				SetEngineStatus(GetPlayerVehicleID(playerid),true);
			}
			else if(!GetEngineStatus(vehicleid))
			{
				if(CoreVehicles[vehicleid][vehHandbrake])
                    return SendErrorMessage(playerid, "Harap nonaktifkan rem tangan kendaraan terlebih dahulu!");

				ShowPlayerFooter(playerid, "Turning on vehicle engine", 2500);
				SetTimerEx("EngineStatus", 2500, false, "dd", playerid, vehicleid);
			}
			PlayerData[playerid][pLastCar] = vehicleid;
		}
		if(newstate == PLAYER_STATE_DRIVER || newstate == PLAYER_STATE_PASSENGER)
		{
			//GameTextForPlayer(playerid, sprintf("~w~%s",GetVehicleNameEx(GetVehicleModel(vehicleid))), 2000, 1);

			PlayerData[playerid][pLastCar] = vehicleid;

			if(PlayerData[playerid][pInjured]) RemovePlayerFromVehicle(GetPlayerVehicleID(playerid));
			if(PlayerData[playerid][pBoombox] != INVALID_PLAYER_ID)
			{
				PlayerData[playerid][pBoombox] = INVALID_PLAYER_ID;
				StopAudioStreamForPlayer(playerid);
			}
		}
		if(newstate == PLAYER_STATE_DRIVER && PlayerData[playerid][pInjured])
		{
			new Float:x, Float:y, Float:z;
			GetPlayerPos(playerid, x, y, z);
			SetPlayerPos(playerid, x, y, z+0.5);
			ApplyAnimation(playerid, "WUZI", "CS_DEAD_GUY", 4.0, false, false, false, true, 0, true);
			ApplyAnimation(playerid, "WUZI", "CS_DEAD_GUY", 4.0, false, false, false, true, 0, true);

			SendCustomMessage(playerid, "Warning", ""YELLOW"Attempts to enter vehicles while being in death mode is bannable.");
		}
		if (GetPVarInt(playerid, "IsAtEvent") == 0)
		{
			if (newstate == PLAYER_STATE_WASTED && PlayerData[playerid][pJailTime] < 1)
			{
				// Speedometer
				if (PlayerData[playerid][pCallLine] != INVALID_PLAYER_ID)
				{
					SendServerMessage(PlayerData[playerid][pCallLine], "Panggilan telah berakhir!");

					CallRemoteFunction("SV_CancelCall", "ddd", playerid, PlayerData[playerid][pCallLine], PhoneFreq[playerid]);
					SetTimerEx("LC_CancelCall", 1000, false, "d", playerid);
				}
				if(!PlayerData[playerid][pInjured])
				{
					SetPlayerInjured(playerid, INVALID_PLAYER_ID, WEAPON_COLLISION);
				}
			}
		}
		if(oldstate == PLAYER_STATE_DRIVER)
		{
			static vehid;

			if((vehid = GetPlayerLastVehicle(playerid)) != INVALID_VEHICLE_ID)
			{
				static vehicle_index;

				if((vehicle_index = Vehicle_GetID(vehid)) != -1)
				{
					if(Vehicle_IsOwner(playerid, vehicle_index))
					{
						Vehicle_Save(vehicle_index);
					}
				}
			}
			/*if(Seatbelt{playerid} == 1)
			{
				Seatbelt{playerid} = 0;
				GameTextForPlayer(playerid, "You have taken off your seatbelt", 3000, 4);
				if(IsPlayerAttachedObjectSlotUsed(playerid, JOB_SLOT)) RemovePlayerAttachedObject(playerid, JOB_SLOT);
			}*/
			if(Helmet[playerid] == 1)
			{
				Helmet[playerid] = 0;
				GameTextForPlayer(playerid, "You have taken off your helmet", 3000, 4);
				if(IsPlayerAttachedObjectSlotUsed(playerid, JOB_SLOT)) RemovePlayerAttachedObject(playerid, JOB_SLOT);
			}
			if(GetEngineStatus(GetPlayerLastVehicle(playerid)))
            {
                EngineStatus(playerid, GetPlayerLastVehicle(playerid));
            }
			AbuseVehicle[playerid] = 0;
		}
		if(newstate == PLAYER_STATE_PASSENGER)
		{
			foreach (new i : Player) if (PlayerData[i][pSpectator] == playerid)
			{
				PlayerSpectateVehicle(i, GetPlayerVehicleID(playerid));
			}
		}
		if (oldstate == PLAYER_STATE_DRIVER || oldstate == PLAYER_STATE_PASSENGER)
		{
			foreach (new i : Player) if (PlayerData[i][pSpectator] == playerid)
			{
				PlayerSpectatePlayer(i, playerid);
			}
		}
		if(newstate == PLAYER_STATE_DRIVER)
		{
			new Float:vhealth;

            AntiCheatGetVehicleHealth(vehicleid, vhealth);
            SetVehicleHealth(vehicleid, vhealth);

			GetVehiclePos(GetPlayerVehicleID(playerid), CoreVehicles[GetPlayerVehicleID(playerid)][vehLastCoords][0], CoreVehicles[GetPlayerVehicleID(playerid)][vehLastCoords][1], CoreVehicles[GetPlayerVehicleID(playerid)][vehLastCoords][2]);

			PlayerData[playerid][pLastVehicle] = vehicleid;
			ShowPlayerSpeedometer(playerid, true);

			if(PlayerData[playerid][pEnterJobVehicle] > 0 && IsPlayerWorkInBus(playerid))
			{
				PlayerData[playerid][pEnterJobVehicle] = 0;
			}
		}
		if(oldstate == PLAYER_STATE_DRIVER)
		{
			if(PlayerData[playerid][pTargetVehicle] != -1)
			{
				if(IsValidVehicle(VehicleData[PlayerData[playerid][pTargetVehicle]][cVehicle]))
				{
					new vehid = PlayerData[playerid][pTargetVehicle];
					new count;
					for(new x = 0; x < 14; x++)
					{
						if(ModQueue[playerid][x] != 0)
						{
							count = 1;
							break;
						}
					}
					if(count == 1 && !IsPlayerInDynamicArea(playerid, AreaData[areaMechanic][0]))
					{
						new component;
						for(new x = 0; x < 14; x++) //removes pending components from the vehicle and then readds saved mods
						{
							component = GetVehicleComponentInSlot(GetPlayerVehicleID(playerid), x);
							if(component != 0) RemoveVehicleComponent(GetPlayerVehicleID(playerid), component);

							if(VehicleData[vehid][cMod][x] && IsVehicleUpgradeCompatible(VehicleData[vehid][cModel], VehicleData[vehid][cMod][x]))
							{
								AddVehicleComponent(VehicleData[vehid][cVehicle], VehicleData[vehid][cMod][x]);
							}
							ModQueue[playerid][x] = 0;
						}
						if(PendingPaintjob[playerid] != -1) ChangeVehiclePaintjob(VehicleData[vehid][cVehicle], 3);
						PendingPaintjob[playerid] = -1;

						if(VehicleData[vehid][cPaintJob] < 3) ChangeVehiclePaintjob(VehicleData[vehid][cVehicle], VehicleData[vehid][cPaintJob]);
					}
				}
			}
		}
		/*if(oldstate == PLAYER_STATE_PASSENGER || oldstate == PLAYER_STATE_DRIVER)
		{
			new Float:vhealth;

            AntiCheatGetVehicleHealth(GetPlayerLastVehicle(playerid), vhealth);
            SetVehicleHealth(GetPlayerLastVehicle(playerid), vhealth);

			if(Vehicle_GetID(GetPlayerLastVehicle(playerid)) != -1)
			{
				defer Vehicle_UpdatePositionEx(Vehicle_GetID(GetPlayerLastVehicle(playerid)));
			}
		}*/
		if(oldstate == PLAYER_STATE_DRIVER)
		{
			ShowPlayerSpeedometer(playerid, false);
		}
		if(IsPlayerWorkInBus(playerid) && oldstate == PLAYER_STATE_DRIVER)
		{
			SendCustomMessage(playerid, "Job", "Pekerjaan bus telah "RED"dibatalkan"WHITE" karena kamu tidak naik bus.");
			CancelBusProgress(playerid);
		}
	}
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    #if defined DEBUG_MODE
	    printf("[debug] OnPlayerRequestClass(PID : %d CLASSID : %d)", playerid, classid);
	#endif

    if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

    if(SQL_IsCharacterLogged(playerid) || SQL_IsLogged(playerid)) {

        TogglePlayerSpectating(playerid, false);
		defer ForceSpawn(playerid);
    } else {
        if (!PlayerData[playerid][pKicked]) {

			SetPVarInt(playerid, "IPBlacklist", 1);
            if(!Blacklist_Check(playerid, "IP", ReturnIP(playerid)))
            DeletePVar(playerid, "IPBlacklist");

            //SetCameraData(playerid);
			LewatClass[playerid] = true;
			SetHealth(playerid, 100);

			// if(!IsPlayerUsingAndroid(playerid)) {
			// 	defer OnCheckFile[5000](playerid);
			// }

           	SQL_CheckAccount(playerid);
	
			//SetTimerEx("SQL_CheckAccount", 5000, false, "d", playerid);
            SetPlayerColor(playerid, X11_GREY);
			RemovePlayerClothing(playerid);
        }
    }
    return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	if(IsPlayerNPC(playerid))
	{
		KickEx(playerid, 400);
		return 1;
	}

	if(!IsPlayerConnected(playerid))
	{
		KickEx(playerid, 400);
		return 1;
	}

	SendErrorMessage(playerid, "Tombol ini dinonaktifkan!.");
	KickEx(playerid, 400);
		
    return 1;
}

Function:ShowVehicleRadial(playerid)
{
	if(IsPlayerConnected(playerid))
	{
		new vehicleid;
		if(IsPlayerInAnyVehicle(playerid))
		{
			vehicleid = GetPlayerVehicleID(playerid);
		}
		else
		{
			vehicleid = GetNearestVehicle(playerid);
		}

		if(vehicleid == INVALID_VEHICLE_ID) return SendErrorMessage(playerid, "Invalid Vehicle ID");

		new toggle[512], string[256], konz[512];
		format(string, sizeof(string), "Vehicle Menus (%s[%d])", GetVehicleNameEx(GetVehicleModel(vehicleid)), vehicleid);

		format(toggle, sizeof(toggle), " \t \n");
		strcat(konz, toggle);

		format(toggle, sizeof(toggle), "%s Engine Status\t%s\n",  GetVehicleNameEx(GetVehicleModel(vehicleid)), (!GetEngineStatus(vehicleid)) ? ("{FF0000}Turned Off") : ("{00FF00}Turned On"));
		strcat(konz, toggle);

		format(toggle, sizeof(toggle), " \t \n");
		strcat(konz, toggle);

		format(toggle, sizeof(toggle), "Vehicle Hood\t%s\n", (GetHoodStatus(vehicleid) == 0) ? ("{FF0000}Closed") : ("{00FF00}Opened"));
		strcat(konz, toggle);

		if(vehicleid == JobVehicle[PlayerData[playerid][pJobVehicle]][Vehicle])
		{
			format(toggle, sizeof(toggle), "Lock Status\t%s\n", (JobVehicle[PlayerData[playerid][pJobVehicle]][Locked]) ? ("{FF0000}Locked") : ("{00FF00}Unlocked"));
			strcat(konz, toggle);
		}
		else
		{
			new carid = -1;
			if((carid = Vehicle_Nearest(playerid)) != -1)
			{
				format(toggle, sizeof(toggle), "Lock Status\t%s\n", (VehicleData[carid][cLocked]) ? ("{FF0000}Locked") : ("{00FF00}Unlocked"));
				strcat(konz, toggle);
			}
			else
			{
				format(toggle, sizeof(toggle), ""RED"Kendaraan Static tidak bisa di kunci\n");
				strcat(konz, toggle);
			}
		}

		format(toggle, sizeof(toggle), "Vehicle Trunk\t%s\n", (!GetTrunkStatus(vehicleid)) ? ("{FF0000}Closed") : ("{00FF00}Opened"));
		strcat(konz, toggle);

		format(toggle, sizeof(toggle), "Front Lights\t%s\n", (!GetLightStatus(vehicleid)) ? ("{FF0000}Disable") : ("{00FF00}Enable"));
		strcat(konz, toggle);

		format(toggle, sizeof(toggle), "Handbrake\t%s\n", (!CoreVehicles[vehicleid][vehHandbrake]) ? ("{FF0000}disengage") : ("{00FF00}engaged"));
		strcat(konz, toggle);

		format(toggle, sizeof(toggle), "Motobike Helmet\t%s\n", (!Helmet[playerid]) ? ("{FF0000}Disable") : ("{00FF00}Enable"));
		strcat(konz, toggle);

		/*format(toggle, sizeof(toggle), "Car Seatbelt\t%s\n", (!Seatbelt{playerid}) ? ("{FF0000}Disable") : ("{00FF00}Enable"));
		strcat(konz, toggle);*/

		Dialog_Show(playerid, RadialVehicle, DIALOG_STYLE_TABLIST, string, konz, "Toggle", "Close");
	}
	return 1;
}

public OnPlayerClickTextDraw(playerid, Text:clickedid)
{
	#if defined DEBUG_MODE
	    printf("[debug] OnPlayerClickTextDraw(PID : %d)", playerid);
	#endif

	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	new str[1500], lstr[2500];

	// Main Phone
	if(clickedid == PhoneTextdraw[main_phone][16])
    {
        if(PhonePage[playerid] == PHONE_HOMESCREEN)
		{
			if(PhonePage[playerid] == PHONE_LOCKSCREEN) ShowLockscreenPagePhone(playerid, false);
			if(PhonePage[playerid] == PHONE_HOMESCREEN) ShowHomePagePhone(playerid, false);
			if(PhonePage[playerid] == PHONE_CONTACT) ShowContactPagePhone(playerid, false);
			if(PhonePage[playerid] == PHONE_SERVICE) ShowServicePagePhone(playerid, false);
			if(PhonePage[playerid] == PHONE_SETTINGS) ShowSettingsPagePhone(playerid, false);
			//ShowPhoneApp(playerid, false);
			if(PhonePage[playerid] == PHONE_MBANKING) ShowMobileBanking(playerid, false);
			if(PhonePage[playerid] == PHONE_DJEK) ShowPhoneDjek(playerid, false);
			if(PhonePage[playerid] == PHONE_PANGGILAN) ShowPanggilanUI(playerid, false);
			if(PhonePage[playerid] == PHONE_ACCEPT_CALL) AcceptCallTD(playerid, false);
			CancelSelectTextDraw(playerid);
			
		}
		else
		CancelSelectTextDraw(playerid);
		SendActionMessage(playerid, "Menutup Hp dan memasukkan kembali ke saku.");
        ShowPlayerPhone(playerid, false);
    }

	if(clickedid == PhoneTextdraw[main_phone][14])
	{
		if(PhonePage[playerid] == PHONE_LOCKSCREEN) ShowLockscreenPagePhone(playerid, false);
		if(PhonePage[playerid] == PHONE_HOMESCREEN) ShowHomePagePhone(playerid, false);
		if(PhonePage[playerid] == PHONE_CONTACT) ShowContactPagePhone(playerid, false);
		if(PhonePage[playerid] == PHONE_SERVICE) ShowServicePagePhone(playerid, false);
		if(PhonePage[playerid] == PHONE_SETTINGS) ShowSettingsPagePhone(playerid, false);
		//ShowPhoneApp(playerid, false);
		if(PhonePage[playerid] == PHONE_MBANKING) ShowMobileBanking(playerid, false);
		if(PhonePage[playerid] == PHONE_DJEK) ShowPhoneDjek(playerid, false);
		if(PhonePage[playerid] == PHONE_PANGGILAN) ShowPanggilanUI(playerid, false);
		if(PhonePage[playerid] == PHONE_ACCEPT_CALL) AcceptCallTD(playerid, false);
		ShowHomePagePhone(playerid, true);
	}

	// Lockscreen
	if(clickedid == PhoneTextdraw[lockscreen][1])
	{
		ShowLockscreenPagePhone(playerid, false);
		ShowHomePagePhone(playerid, true);
	}

	// Application
	if(clickedid == PhoneTextdraw[myapplication][1])
	{
		ShowHomePagePhone(playerid, false);
		ShowContactPagePhone(playerid, true);
	}
	if(clickedid == PhoneTextdraw[myapplication][2])
	{
		if(IsPlayerWorkInBus(playerid) || PlayerData[playerid][pCarStealing] || PlayerData[playerid][pMissions] > 0) return SendErrorMessage(playerid, "Tidak bisa membuka GPS saat bekerja");
		if(PlayerData[playerid][pCarStealing]) return SendErrorMessage(playerid, "Tidak bisa membuka GPS saat melakukan carstealing");

		DisableWaypoint(playerid);
		DisplayGPS(playerid);
	}
	if(clickedid == PhoneTextdraw[myapplication][3])
	{
		new Float:x,
        Float:y,
        Float:z,
        nearhim[855],
        count;

		GetPlayerPos(playerid, x, y, z);


		foreach(new i : Player) if(PlayerData[i][pLogged] && i != playerid && IsPlayerInRangeOfPoint(i, 2.0, x, y, z)) {
			if(count % 2 == 0) strcat(nearhim, sprintf(""WHITE"Kantong - "YELLOW"%s (%d)\n", ReturnName(i), i));
			else strcat(nearhim, sprintf(""GREY"Kantong - "YELLOW"%s (%d)\n", ReturnName(i), i));
			count ++;
		}
		if(count > 0) Dialog_Show(playerid, SHARE_PHONE_NUMBER, DIALOG_STYLE_LIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Airdrop", sprintf("%s", nearhim), "Pilih", "Batal");
		else SendErrorMessage(playerid, "Tidak ada orang di sekitar mu");
	}
	if(clickedid == PhoneTextdraw[myapplication][4])
	{
		ShowHomePagePhone(playerid, false);
		ShowMobileBanking(playerid, true);
	}
	if(clickedid == PhoneTextdraw[myapplication][5])
	{
		ShowHomePagePhone(playerid, false);
		ShowServicePagePhone(playerid, true); 
	}
	if(clickedid == PhoneTextdraw[myapplication][6])
	{
		ShowHomePagePhone(playerid, false);
		ShowSettingsPagePhone(playerid, true);
	}
	if(clickedid == PhoneTextdraw[myapplication][7])
	{
		new mquery[500];
		/*strcat(lstr, "Contact Name\tStatus\tNumber\n");
		for(new i = 0; i < MAX_PHONECONTACTS; i++)
		{
			if(PhoneContacts[playerid][i][cID] != 0)
			{
				format(str, sizeof(str), "%s\t%s\t(#%i)\n", PhoneContacts[playerid][i][ContactName], IsNumberOnline(PhoneContacts[playerid][i][ContactNumber]) ? ""YELLOW"(Online)"WHITE"" : ""RED"(Offline)"WHITE"", PhoneContacts[playerid][i][ContactNumber]);
				strcat(lstr, str);
			}
		}
		Dialog_Show(playerid, ContactsView, DIALOG_STYLE_TABLIST_HEADERS,  ""WHITE""SERVER_NAME" "SERVER_LOGO" WhatsApp", lstr, "Select", "Back");*/
		mysql_format(g_SQL, mquery, sizeof(mquery), "SELECT * FROM sms WHERE TextTo = %i OR TextFrom = %i GROUP BY TextTo ORDER BY id ASC LIMIT 20 OFFSET 0", PlayerData[playerid][pNumber], PlayerData[playerid][pNumber]);
		mysql_pquery(g_SQL, mquery, "ShowSMSList", "i", playerid);
	}
	if(clickedid == PhoneTextdraw[myapplication][8])
	{
		Dialog_Show(playerid, Spotify, DIALOG_STYLE_LIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Spotify", "Masukkan URL Musik\nHentikan Musik", "Pilih", "Batal");
	}
	if(clickedid == PhoneTextdraw[myapplication][9])
	{
		if(strcmp(PlayerData[playerid][pTweetName], "None", true) == 0)
		{
			Dialog_Show(playerid, DIALOG_CREATE_TWITTER, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Buat Akun Twitter", ""WHITE"Kamu tidak memiliki akun twitter!\nmasukan nama yang ingin Kamu gunakan menjadi akun twitter\n\n"RED"PENTING: "WHITE"Nama yang di gunakan menggunakan dilarang mengandung sara & menyinggung orang lain", "Pilih", "Batal");
		}
		else
		{
			DisplayTweetMenu(playerid);
		}
	}
	if(clickedid == PhoneTextdraw[myapplication][10])
	{
		ShowHomePagePhone(playerid, false);
		ShowPhoneDjek(playerid, true);
	}
	if(clickedid == PhoneTextdraw[myapplication][11])
	{
		Dialog_Show(playerid, AdvertisementMenu, DIALOG_STYLE_LIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Advertisement Menu", "Make a (Ad)vertisement\nShow Advertisement", "Select", "Close");
	}
	if(clickedid == PhoneTextdraw[myapplication][12])
	{
		Dialog_Show(playerid, DialNumber, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Call", "Silakan masukkan nomor yang ingin Anda hubungi di bawah ini:", "Dial", "Back");
	}

	// Contact
	if(clickedid == PhoneTextdraw[contact][2])
	{
		Dialog_Show(playerid, ContactsAdd1, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Buat Kontak Baru", "Silakan masukkan NAMA kontak baru:", "Next", "Menu");
	}
	if(clickedid == PhoneTextdraw[contact][4])
	{
		strcat(lstr, "Contact Name\tStatus\tNumber\n");
		for(new i = 0; i < MAX_PHONECONTACTS; i++)
		{
			if(PhoneContacts[playerid][i][cID] != 0)
			{
				format(str, sizeof(str), "%s\t%s\t(#%i)\n", PhoneContacts[playerid][i][ContactName], IsNumberOnline(PhoneContacts[playerid][i][ContactNumber]) ? ""YELLOW"(Online)"WHITE"" : ""RED"(Offline)"WHITE"", PhoneContacts[playerid][i][ContactNumber]);
				strcat(lstr, str);
			}
		}
		Dialog_Show(playerid, ContactsView, DIALOG_STYLE_TABLIST_HEADERS,  ""WHITE""SERVER_NAME" "SERVER_LOGO" Daftar Kontak", lstr, "Select", "Back");
	}
	if(clickedid == PhoneTextdraw[contact][6])
	{
		strcat(lstr, "Contact Name\tStatus\tNumber\n");
		for(new i = 0; i < MAX_PHONECONTACTS; i++)
		{
			if(PhoneContacts[playerid][i][cID] != 0)
			{
				format(str, sizeof(str), "%s\t%s\t(#%i)\n", PhoneContacts[playerid][i][ContactName], IsNumberOnline(PhoneContacts[playerid][i][ContactNumber]) ? ""YELLOW"(Online)"WHITE"" : ""RED"(Offline)"WHITE"", PhoneContacts[playerid][i][ContactNumber]);
				strcat(lstr, str);
			}
		}

		Dialog_Show(playerid, ContactsEditMenu, DIALOG_STYLE_TABLIST_HEADERS, ""WHITE""SERVER_NAME" "SERVER_LOGO" Edit Kontak", lstr, "Edit", "Back");
	}
	if(clickedid == PhoneTextdraw[contact][8])
	{
		strcat(lstr, "Contact Name\tStatus\tNumber\n");
		for(new i = 0; i < MAX_PHONECONTACTS; i++)
		{
			if(PhoneContacts[playerid][i][cID] != 0)
			{
				format(str, sizeof(str), "%s\t%s\t(#%i)\n", PhoneContacts[playerid][i][ContactName], IsNumberOnline(PhoneContacts[playerid][i][ContactNumber]) ? ""YELLOW"(Online)"WHITE"" : ""RED"(Offline)"WHITE"", PhoneContacts[playerid][i][ContactNumber]);
				strcat(lstr, str);
			}
		}
		Dialog_Show(playerid, ContactsDelete, DIALOG_STYLE_TABLIST_HEADERS, ""WHITE""SERVER_NAME" "SERVER_LOGO" Hapus Kontak", lstr, "Delete", "Back");
	}

	// Banking
	if(clickedid == PhoneTextdraw[banking][11])
	{
		new gstr[2000];

		new count = 0;
		foreach(new i: Player)
		{
			if(PlayerData[i][pLogged] && i != playerid)
			{
				strcat(gstr,ReturnName(i));
				strcat(gstr,"\n");
				count++;
			}
		}
		if(count > 0) Dialog_Show(playerid,BankTransfer1,DIALOG_STYLE_LIST,"FLEECA Bank - Transfer - (( Pilih Pemain untuk Menerima ))",gstr,"Next","Cancel");
		else ShowMessage(playerid,"FLEECA Bank - Transfer","Maaf, tidak ada orang yang bisa Kamu transfer.", "OK");
	}

	// Layanan Pemerintah
	if(clickedid == PhoneTextdraw[service][2])
	{
		Dialog_Show(playerid, DIALOG_POLICE_MESSAGE, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Polisi", ""RED"PERHATIAN: "WHITE"Membuat laporan palsu atau melakukan penghinaan kepada institusi dapat dikenakan pidana\nTuliskan pesan yang ingin kamu kirim ke polisi di bawah ini:", "Pilih", "Batal");
	}
	if(clickedid == PhoneTextdraw[service][3])
	{
		Dialog_Show(playerid, DIALOG_EMS_MESSAGE, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Ems", ""RED"PERHATIAN: "WHITE"Membuat laporan palsu atau melakukan penghinaan kepada institusi dapat dikenakan pidana\nTuliskan pesan yang ingin kamu kirim ke ems di bawah ini:", "Pilih", "Batal");
	}
	if(clickedid == PhoneTextdraw[service][4])
	{
		Dialog_Show(playerid, DIALOG_MEKANIK_MESSAGE, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Mekanik", ""RED"PERHATIAN: "WHITE"Membuat laporan palsu atau melakukan penghinaan kepada institusi dapat dikenakan pidana\nTuliskan pesan yang ingin kamu kirim ke mekanik di bawah ini:", "Pilih", "Batal");
	}
	if(clickedid == PhoneTextdraw[service][5])
	{ 
		Dialog_Show(playerid, DIALOG_PEDAGANG_MESSAGE, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Pedagang", ""RED"PERHATIAN: "WHITE"Membuat laporan palsu atau melakukan penghinaan kepada institusi dapat dikenakan pidana\nTuliskan pesan yang ingin kamu kirim ke pedagang di bawah ini:", "Pilih", "Batal");
	}
	if(clickedid == PhoneTextdraw[service][6])  
	{ 
		PlayerData[playerid][pTaxiCalled] = 1;   
		PlayerPlaySound(playerid, 3600, 0.0, 0.0, 0.0);

		SendCustomMessage(playerid, "Taxi", "The taxi department has been notified of your call.");
		SendJobMessage(JOB_TAXI, X11_BLUE, "Dispatch: "WHITE"Client: [ "YELLOW"(id: %d) "LIGHT_BLUE" %s "WHITE"] Last know position: [ "YELLOW"%s "WHITE"]", playerid, ReturnName(playerid), GetPlayerLocation(playerid));
		SendJobMessage(JOB_TAXI, X11_LIGHTBLUE, "NOTE: Use Command '/acceptcall' to respond to the call");
	}
	if(clickedid == PhoneTextdraw[service][17])  
	{
		new invStr[500];
		new count = 0;

		strcat(invStr, "Reason\tAmmount\tDate\tInvoice By\n");
		for (new i = 0; i < MAX_PLAYER_INVOICES; i ++)
		{
			if (InvoiceData[playerid][i][invoiceExists])
			{
				count ++;
				if(i % 2 == 0) strcat(invStr, sprintf(""GREY"%s\t"GREY"%s\t"GREY"%s\t"GREY"%s\n", InvoiceData[playerid][i][invoiceReason], FormatNumber(InvoiceData[playerid][i][invoiceFee]), InvoiceData[playerid][i][invoiceDate], GetSQLName(InvoiceData[playerid][i][invoiceBy])));
				else strcat(invStr, sprintf(""WHITE"%s\t"WHITE"%s\t"WHITE"%s\t"WHITE"%s\n", InvoiceData[playerid][i][invoiceReason], FormatNumber(InvoiceData[playerid][i][invoiceFee]), InvoiceData[playerid][i][invoiceDate], GetSQLName(InvoiceData[playerid][i][invoiceBy])));
			}
		}
		if(count == 0) return Dialog_Show(playerid, DIALOG_NONE, DIALOG_STYLE_MSGBOX, ""WHITE""SERVER_NAME" "SERVER_LOGO" Invoice List", "Tidak ada invoice yang harus di bayarkan.", "Pay", "Close");
		else return Dialog_Show(playerid, DIALOG_INVOICE, DIALOG_STYLE_TABLIST_HEADERS, ""WHITE""SERVER_NAME" "SERVER_LOGO" Invoice List", invStr, "Pay", "Close");
	}

	// Pengaturan
	if(clickedid == PhoneTextdraw[settings][2])
	{
		Dialog_Show(playerid, DIALOG_NONE, DIALOG_STYLE_MSGBOX, ""WHITE""SERVER_NAME" "SERVER_LOGO" Phone Details", ""WHITE">> {0098F2}%s's"WHITE" Phone Information <<\n\n"WHITE"Phone Model: Genius Velphone\nPhone Number: %d\nPhone network: S.A. Mobile\nCell Phone Signal: {16BD00}Full service"WHITE"\nCell Phone Status: {16BD00}Online\n"WHITE"Credits: "GREEN"%s"WHITE"", "Close", "", ReturnName(playerid), PlayerData[playerid][pNumber], FormatNumber(PlayerData[playerid][pCredits]));
	}
	if(clickedid == PhoneTextdraw[settings][4])
	{
		if (PlayerData[playerid][pCallLine] != INVALID_PLAYER_ID)
		{
			CallRemoteFunction("SV_CancelCall", "ddd", playerid, PlayerData[playerid][pCallLine], PhoneFreq[playerid]);
			SetTimerEx("LC_CancelCall", 1000, false, "d", playerid);
		}
		PlayerData[playerid][pPhoneOff] = 1;
		RemovePlayerAttachedObject(playerid, 3);
		SendServerMessage(playerid, "Successfully turned ~r~off~w~ the phone.");
		CancelSelectTextDraw(playerid);
		ShowPlayerPhone(playerid, false);
	}

	// Gojek
	if(clickedid == PhoneTextdraw[djek][1])
	{
		if(Emergency_GetCount(playerid) > 0) return SendErrorMessage(playerid, "Kamu sudah memiliki pesan aktif!");
		Dialog_Show(playerid, DIALOG_CALL_TRANSPORT2, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Motor", "Kirimkan pesan kepada driver ojek dibawah ini: ", "Kirim", "Batal");
	}
	if(clickedid == PhoneTextdraw[djek][2])
	{
		if(Emergency_GetCount(playerid) > 0) return SendErrorMessage(playerid, "Kamu sudah memiliki pesan aktif!");
		Dialog_Show(playerid, DIALOG_CALL_GOCAR, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Mobil", "Kirimkan pesan kepada driver gocar dibawah ini: ", "Kirim", "Batal");
	}
	if(clickedid == PhoneTextdraw[djek][3])
	{
		if(Emergency_GetCount(playerid) > 0) return SendErrorMessage(playerid, "Kamu sudah memiliki pesan aktif!");
		Dialog_Show(playerid, DIALOG_CALL_GOFOOD, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Food Deliver", "Kirimkan pesan kepada driver gofood dibawah ini: ", "Kirim", "Batal");
	}

	// Accept Call
	if(clickedid == PhoneTextdraw[AcceptCall][3])
	{
		SendServerMessage(playerid, "Your call ~r~rejected!");

		CallRemoteFunction("SV_CancelCall", "ddd", playerid, PlayerData[playerid][pCallLine], PhoneFreq[playerid]);
		SetTimerEx("LC_CancelCall", 1000, false, "d", playerid);
	}
	if(clickedid == PhoneTextdraw[AcceptCall][2])
	{
		if (!PlayerData[playerid][pIncomingCall])
			return SendErrorMessage(playerid, "Tidak ada panggilan masuk untuk diterima.");

		if (PlayerData[playerid][pCuffed])
			return SendErrorMessage(playerid, "Kamu tidak dapat menggunakan perintah ini sekarang.");

		if (PlayerData[playerid][pPhoneOff])
			return SendErrorMessage(playerid, "Ponsel Kamu harus dihidupkan terlebih dahulu.");

		CancelSelectTextDraw(playerid);
		CancelSelectTextDraw(PlayerData[playerid][pCallLine]);

		ShowPlayerPhone(PlayerData[playerid][pCallLine], false);
		ShowPlayerPhone(playerid, false);

		ShowPlayerPhone(PlayerData[playerid][pCallLine], true);
		ShowPanggilanUI(PlayerData[playerid][pCallLine], true);

		ShowPlayerPhone(playerid, true);
		ShowPanggilanUI(playerid, true);

		PlayerData[playerid][pIncomingCall] = 0;
		PlayerData[PlayerData[playerid][pCallLine]][pIncomingCall] = 0;

		PhoneFreq[playerid] = 300 + playerid;
		PhoneFreq[PlayerData[playerid][pCallLine]] = 300 + playerid;

		PlayerData[playerid][pCallTime] = 0;
		PlayerData[PlayerData[playerid][pCallLine]][pCallTime] = 0;

		PlayerData[playerid][pCallTimer] = SetTimerEx("CallTime", 1000, true, "d", playerid);
		PlayerData[PlayerData[playerid][pCallLine]][pCallTimer] = SetTimerEx("CallTime", 1000, true, "d", PlayerData[playerid][pCallLine]);

		SetTimerEx("SetPlayerPhone", 1000, false, "d", playerid);

		SendServerMessage(playerid, "You have answered an incoming call.");
		SendServerMessage(PlayerData[playerid][pCallLine], "Your call has been received.");

		SetPlayerSpecialAction(playerid, SPECIAL_ACTION_USECELLPHONE);
		SetPlayerSpecialAction(PlayerData[playerid][pCallLine], SPECIAL_ACTION_USECELLPHONE);

		if(!IsPlayerAttachedObjectSlotUsed(playerid, 9)) SetPlayerAttachedObject(playerid, 9, 19942, 2, 0.0300, 0.1309, -0.1060, 118.8998, 19.0998, 164.2999);
		if(!IsPlayerAttachedObjectSlotUsed(PlayerData[playerid][pCallLine], 9)) SetPlayerAttachedObject(PlayerData[playerid][pCallLine], 9, 19942, 2, 0.0300, 0.1309, -0.1060, 118.8998, 19.0998, 164.2999);

		SendActionMessage(playerid, "Receive incoming calls.");
	}

	// Panggilan
	if(clickedid == PhoneTextdraw[PanggilanTD][1])
	{
		if (PlayerData[playerid][pCallLine] == INVALID_PLAYER_ID)
			return SendErrorMessage(playerid, "No call to end.");
		if (PlayerData[playerid][pIncomingCall])
		{
			SendServerMessage(playerid, "You have ~r~rejected~w~ the incoming call.");
			SendServerMessage(PlayerData[playerid][pCallLine], "Your call has been rejected.");
			SendActionMessage(playerid, sprintf("Rejecting incoming calls."));
		}
		else
		{
			SendServerMessage(playerid, "You have ~r~closed~w~ the call.");
			SendServerMessage(PlayerData[playerid][pCallLine], "Your call has been closed.");
			SendActionMessage(playerid, sprintf("Has hung up their cellphone."));
			SendActionMessage(PlayerData[playerid][pCallLine], sprintf("Close the call!."));
		}
		CallRemoteFunction("SV_CancelCall", "ddd", playerid, PlayerData[playerid][pCallLine], PhoneFreq[playerid]);
		SetTimerEx("LC_CancelCall", 1000, false, "d", playerid);
	}

	// 	//RADIAL// menu // radial menu
	if(clickedid == RadialTD[4])
	{
		ShowPlayerRadialMenu(playerid, false);
	}
	if(clickedid == RadialTD[0])
	{
		ShowVehicleRadial(playerid);
		ShowPlayerRadialMenu(playerid, false);
	}
	if(clickedid == RadialTD[1]) //NEXT RADIAL
	{
	    ShowPlayerRadialMenu(playerid, false);
		ShowPlayerRadialMenu2(playerid, true);
	}
	if(clickedid == RadialTD[2]) //ACTION
	{
		ShowPlayerRadialMenu(playerid, false);
		DisplayFactionMenu(playerid);
	}
	if(clickedid == RadialTD[3]) //DOCUMENT
	{
		strcat(str, ""SKYBLUE"Pilihan\t"SKYBLUE"Keterangan\n");
        strcat(str, ""WHITE"All Licenses\t"WHITE"melihat seluruh jenis licenses\n");
        strcat(str, ""GREY"Perlihatkan licences\t"GREY"memperlihatkan seluruh jenis licenses\n");
        strcat(str, ""WHITE"Kartu Tanda Penduduk\t"WHITE"melihat kartu tanda penduduk\n");
        strcat(str, ""GREY"Medicare\t"GREY"melihat kartu kesehatan/BPJS\n");
        strcat(str, ""WHITE"Perlihatkan Medicare\t"WHITE"memperlihatkan kartu kesehatan/BPJS\n");
        strcat(str, ""GREY"Memperlihatkan Kartu Tanda Penduduk\t"GREY"memperlihatkan kartu tanda penduduk\n");
		strcat(str, ""WHITE"Status hubungan\t"WHITE"melihat persentasi hubungan DATE/MARRY\n");
        strcat(str, ""GREY"Daftar Properti\t"GREY"melihat properti yang dimiliki\n");
        strcat(str, ""WHITE"Daftar Kendaraan\t"WHITE"melihat daftar kendaraan yang dimiliki\n");
        Dialog_Show(playerid, DIALOG_DOKUMEN, DIALOG_STYLE_TABLIST_HEADERS, ""WHITE""SERVER_NAME" "SERVER_LOGO" Dokumen",str, "Pilih", "Batal");
		ShowPlayerRadialMenu(playerid, false);
	}

	//RADIAL 2
	if(clickedid == RadialTD2[4])
	{
		ShowPlayerRadialMenu2(playerid, false);
		ShowPlayerRadialMenu(playerid, true);
	}
	if(clickedid == RadialTD2[0]) // INVENTORY
	{
		ShowPlayerRadialMenu2(playerid, false);
		DisplayPlayerInventory(playerid);
	}
	if(clickedid == RadialTD2[1]) //PHONE
	{
		ShowPlayerRadialMenu2(playerid, false);
		DisplayPlayerPhone(playerid);
	}
	if(clickedid == RadialTD2[2]) //RADIO
	{
		if(PlayerData[playerid][pTied] || PlayerData[playerid][pCuffed]) return SendErrorMessage(playerid, "Kamu sedang di borgol/diikat.");
		if(!Inventory_HasItem(playerid, "Walkie Talkie")) return SendErrorMessage(playerid, "Kamu tidak memiliki walkie talkie");
		if(!OpenRadio[playerid])
		{
			ShowWalkieTalkieTD(playerid, true);
		}
		else
		{
			ShowWalkieTalkieTD(playerid, false);
		}
		forex(txd, 33)
        {
            TextDrawHideForPlayer(playerid, RadialTD2[txd]);
        }
	}
	if(clickedid == RadialTD2[3]) //ACC
	{
		ShowPlayerRadialMenu2(playerid, false);
		cl_ShowClothingMenu(playerid);
	}	
	
	// Chose Character
	if(clickedid == ChoseCharacter[7])
	{
		if(SelectCharIndex[playerid] <= 0)
		{
			SelectCharIndex[playerid] = MAX_CHARACTERS - 1;
			if(CharacterList[playerid][SelectCharIndex[playerid]][0] == EOS)
			{
				SetPlayerSkin(playerid, 1);
			}
			else
			{
				SetPlayerSkin(playerid, CharSkin[playerid][SelectCharIndex[playerid]]);
			}
			UpdateCharacterInformationTD(playerid);
			return 1;
		}
		SelectCharIndex[playerid] --;

		if(SelectCharIndex[playerid] == -1) SelectCharIndex[playerid] = 0;
		if(CharacterList[playerid][SelectCharIndex[playerid]][0] == EOS)
		{
			SetPlayerSkin(playerid, 1);
		}
		else
		{
			SetPlayerSkin(playerid, CharSkin[playerid][SelectCharIndex[playerid]]);
		}
		UpdateCharacterInformationTD(playerid);
	}
	if(clickedid == ChoseCharacter[1])
	{
		if(SelectCharIndex[playerid] <= 0)
		{
			SelectCharIndex[playerid] = MAX_CHARACTERS - 1;
			if(CharacterList[playerid][SelectCharIndex[playerid]][0] == EOS)
			{
				SetPlayerSkin(playerid, 59);
			}
			else
			{
				SetPlayerSkin(playerid, CharSkin[playerid][SelectCharIndex[playerid]]);
			}
			UpdateCharacterInformationTD(playerid);
			return 1;
		}
		SelectCharIndex[playerid] --;
		if(CharacterList[playerid][SelectCharIndex[playerid]][0] == EOS)
		{
			SetPlayerSkin(playerid, 59);
		}
		else
		{		
			SetPlayerSkin(playerid, CharSkin[playerid][SelectCharIndex[playerid]]);
		}
		UpdateCharacterInformationTD(playerid);
	}
	if(clickedid == ChoseCharacter[2])
	{
		if(SelectCharIndex[playerid] >= MAX_CHARACTERS - 1)
		{
			SelectCharIndex[playerid] = 0;
			if(CharacterList[playerid][SelectCharIndex[playerid]][0] == EOS)
			{
				SetPlayerSkin(playerid, 59);
			}
			else
			{
				SetPlayerSkin(playerid, CharSkin[playerid][SelectCharIndex[playerid]]);
			}
			UpdateCharacterInformationTD(playerid);
			return 1;
		}
		SelectCharIndex[playerid] ++;
		if(CharacterList[playerid][SelectCharIndex[playerid]][0] == EOS)
		{
			SetPlayerSkin(playerid, 59);
		}
		else
		{
			SetPlayerSkin(playerid, CharSkin[playerid][SelectCharIndex[playerid]]);
		}
		UpdateCharacterInformationTD(playerid);
	}
	if(clickedid == ChoseCharacter[0])
	{
		if (CharacterList[playerid][SelectCharIndex[playerid]][0] == EOS)
		{
			HideChoseCharacterTextDraw(playerid);
			TogglePlayerSpectating(playerid, 0);
			ShowPassport(playerid);
		}
		else SendErrorMessage(playerid, "Karakter ini telah terdaftar");
	}
	if(clickedid == ChoseCharacter[13])
	{
		if (CharacterList[playerid][SelectCharIndex[playerid]][0] == EOS)
			return SendErrorMessage(playerid, "Karakter masih kosong");	
		HideChoseCharacterTextDraw(playerid);
		TogglePlayerSpectating(playerid, 0);	
		PlayerData[playerid][pListitem] = SelectCharIndex[playerid];
		PlayerData[playerid][pCharacter] = SelectCharIndex[playerid];	
		SetPlayerName(playerid, CharacterList[playerid][PlayerData[playerid][pCharacter]]);		
		if(!Blacklist_Check(playerid, "Characters", ReturnName(playerid))) {
			mysql_tquery(g_SQL, sprintf("SELECT * FROM `users` WHERE `Username`='%s' ORDER BY `pID` ASC LIMIT 1;", CharacterList[playerid][PlayerData[playerid][pCharacter]]), "OnQueryFinished", "dd", playerid, THREAD_LOAD_CHARACTERS);	
			format(PlayerData[playerid][pName], MAX_PLAYER_NAME, CharacterList[playerid][PlayerData[playerid][pCharacter]]);
		}
	}

	// Clothing Store
	if(clickedid == ClothingStoreTD[3])
	{
		if(PlayerData[playerid][pOnDuty]) return SendErrorMessage(playerid, "Kamu tidak bisa membeli pakaian saat sedang bertugas");

		ShowSkinSelectorTD(playerid, true);
		TempPurchasedSkin[playerid] = 0;
	}
	if(clickedid == SkinSelectionTD[0]) // Next
	{
		if(PlayerData[playerid][pGender] == 1)
		{
			TempPurchasedSkin[playerid]++;
			if(TempPurchasedSkin[playerid] >= sizeof(g_aMaleSkins))
				TempPurchasedSkin[playerid] = 0; 

			SetPlayerSkin(playerid, g_aMaleSkins[TempPurchasedSkin[playerid]]);
		}
		else
		{
			TempPurchasedSkin[playerid]++;
			if(TempPurchasedSkin[playerid] >= sizeof(g_aFemaleSkins))
				TempPurchasedSkin[playerid] = 0;

			SetPlayerSkin(playerid, g_aFemaleSkins[TempPurchasedSkin[playerid]]);
		}
	}

	if(clickedid == SkinSelectionTD[1]) // Previous
	{
		if(PlayerData[playerid][pGender] == 1)
		{
			if(TempPurchasedSkin[playerid] == 0)
				TempPurchasedSkin[playerid] = sizeof(g_aMaleSkins) - 1; 
			else
				TempPurchasedSkin[playerid]--;

			SetPlayerSkin(playerid, g_aMaleSkins[TempPurchasedSkin[playerid]]);
		}
		else
		{
			if(TempPurchasedSkin[playerid] == 0)
				TempPurchasedSkin[playerid] = sizeof(g_aFemaleSkins) - 1; 
			else
				TempPurchasedSkin[playerid]--;

			SetPlayerSkin(playerid, g_aFemaleSkins[TempPurchasedSkin[playerid]]);
		}
	}

	if(clickedid == SkinSelectionTD[7])
	{
		ShowSkinSelectorTD(playerid, false);
		if(GetPlayerSkin(playerid) != PlayerData[playerid][pSkin])
		{
			SetPlayerSkin(playerid, PlayerData[playerid][pSkin]);
		}
	}
	if(clickedid == SkinSelectionTD[4])
	{
		if(GetMoney(playerid) < 50) return SendErrorMessage(playerid, "Kamu tidak memiliki $50 untuk membeli skin");

		TakeMoney(playerid, 50);
		UpdatePlayerSkin(playerid, GetPlayerSkin(playerid));
		
		static bizid = -1;
		if ((bizid = Business_Inside(playerid)) != -1)
		{
			if (BusinessData[bizid][bizProducts] < 1)
		    	return SendErrorMessage(playerid, "This business is out of stock.");

			BusinessData[bizid][bizProducts]--;
			BusinessData[bizid][bizVault] += 50;

			Business_Save(bizid);
		}
		
	}
	if(clickedid == SkinSelectionTD[8])
	{
		ShowSkinSelectorTD(playerid, false);
		if(GetPlayerSkin(playerid) != PlayerData[playerid][pSkin])
		{
			SetPlayerSkin(playerid, PlayerData[playerid][pSkin]);
		}
	}
	if(clickedid == SkinSelectionTD[8])
	{
		ShowSkinSelectorTD(playerid, false);
		if(GetPlayerSkin(playerid) != PlayerData[playerid][pSkin])
		{
			SetPlayerSkin(playerid, PlayerData[playerid][pSkin]);
		}
	}
	if(clickedid == ClothingStoreTD[1])
	{
		ShowSkinSelectorTD(playerid, false);
		if(GetPlayerSkin(playerid) != PlayerData[playerid][pSkin])
		{
			SetPlayerSkin(playerid, PlayerData[playerid][pSkin]);
		}
	}
	


	// Safe
    if(clickedid == SafeTextdraw[4])
	{
        SafeCracking_SetNumber(playerid, (CurSafeNumber[playerid] - 1 < 0) ? MAX_NUMBER : CurSafeNumber[playerid] - 1);
        PlayerPlaySound(playerid, 17803, 0.0, 0.0, 0.0);
        return 1;
    }
    if(clickedid == SafeTextdraw[6])
	{
        SafeCracking_SetNumber(playerid, (CurSafeNumber[playerid] + 1 > MAX_NUMBER) ? 0 : CurSafeNumber[playerid] + 1);
        PlayerPlaySound(playerid, 17803, 0.0, 0.0, 0.0);
        return 1;
    }
    if(clickedid == SafeTextdraw[8])
    {
        new id = CrackingSafeID[playerid];
        if(id == -1) return SafeCracking_SetUIState(playerid, 0);
        if(CurSafeNumber[playerid] == SafeCracking_GetLockNumber(id)) {
            // correct number, open a lock/crack the safe if no locks left
            new idx = SafeCracking_GetLockIndex(id);
			if(idx == -1) {
				SafeCracking_UnlockSafe(id);
				SafeCracking_ResetPlayer(playerid);
				Streamer_Update(playerid);
			}
			else
			{
            	SafeData[id][SafeLocks][idx] = true;
            	// update textdraws
            	SafeCracking_UpdateLocks(playerid);
				// reset number
				SafeCracking_SetNumber(playerid, 0);
				// lock check
				if(SafeCracking_GetLockIndex(id) == -1)
            	{
					SafeCracking_UnlockSafe(id);
					SafeCracking_ResetPlayer(playerid);
					Streamer_Update(playerid);
            	}
			}
			PlayerPlaySound(playerid, 1083, 0.0, 0.0, 0.0);
        }
		else
		{
            // incorrect number, reset locks
            for(new i; i < 3; i++)
			{
			    SafeData[id][SafeNumbers][i] = RandomEx(0, MAX_NUMBER);
				SafeData[id][SafeLocks][i] = false;
            }
            SafeCracking_UpdateLocks(playerid);
            SafeCracking_SetNumber(playerid, 0);
            SendErrorMessage(playerid, "Nomor salah, kata sandi telah diubah.");
            PlayerPlaySound(playerid, 1085, 0.0, 0.0, 0.0);
        }
    }
	
	if(clickedid == ClothingStoreTD[4])
	{
		ShowEditClothingMode(playerid, 1);
	}
	if(clickedid == ClothingStoreTD[1])
	{
		ShowEditClothingMode(playerid, 0);
		ShowClothingStore(playerid, 0);
		CancelSelectTextDraw(playerid);
	}
	if(clickedid == EditingClothingTD[2])
	{
		ShowEditClothingMode(playerid, 0);
	}
	if(clickedid == EditingClothingTD[3])
	{
		new clothingid = cl_dataslot[playerid][cl_selected[playerid]];

		if(ClothingData[playerid][clothingid][cl_object])
		{
			if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][clothingid][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][clothingid][cl_slot]);
			ClothingData[playerid][clothingid][cl_object] = 0;

			new query[128];
			mysql_format(g_SQL, query, sizeof(query), "DELETE FROM `clothing` WHERE `owner` = '%d' and `id` = '%d' LIMIT 1",PlayerData[playerid][pID], ClothingData[playerid][clothingid][cl_sid]);
			mysql_tquery(g_SQL, query);

			SendServerMessage(playerid, "You dropped your ~y~%s - #%d", ClothingData[playerid][clothingid][cl_name], clothingid + 1);

			SetCooldown(playerid, COOLDOWN_CLOTHES, 5);
			UpdateClothingTextdraw(playerid);
		}
		else SendErrorMessage(playerid, "Tidak ada aksesoris yang bisa di hapus");
	}
	if(clickedid == EditingClothingTD[6])
	{
		if(cl_selected[playerid] <= 0)
		{
			if(PlayerData[playerid][pVIP] <= 1) cl_selected[playerid] = 4;
			if(PlayerData[playerid][pVIP] == 2) cl_selected[playerid] = 4;
			if(PlayerData[playerid][pVIP] == 3) cl_selected[playerid] = 4;
			cl_dataslot[playerid][cl_selected[playerid]] = cl_selected[playerid];
			UpdateClothingTextdraw(playerid);
		}
		else
		{
			cl_selected[playerid] --;
			cl_dataslot[playerid][cl_selected[playerid]] = cl_selected[playerid];
			UpdateClothingTextdraw(playerid);
		}
	}
	if(clickedid == EditingClothingTD[8])
	{
		if(PlayerData[playerid][pVIP] <= 1 && cl_selected[playerid] == 5)
		{
			cl_selected[playerid] = 0;
			cl_dataslot[playerid][cl_selected[playerid]] = cl_selected[playerid];
			UpdateClothingTextdraw(playerid);
		}
        if(PlayerData[playerid][pVIP] == 2 && cl_selected[playerid] == 6)
		{
			cl_selected[playerid] = 0;
			cl_dataslot[playerid][cl_selected[playerid]] = cl_selected[playerid];
			UpdateClothingTextdraw(playerid);
		}
		if(PlayerData[playerid][pVIP] == 3 && cl_selected[playerid] == 7)
		{
			cl_selected[playerid] = 0;
			cl_dataslot[playerid][cl_selected[playerid]] = cl_selected[playerid];
			UpdateClothingTextdraw(playerid);
		}
		else
		{
			cl_selected[playerid] ++;
			cl_dataslot[playerid][cl_selected[playerid]] = cl_selected[playerid];
			UpdateClothingTextdraw(playerid);
		}
	}
	if(clickedid == EditingClothingTD[11])
	{
		ShowClothingDialog(playerid, 0);

		//if((cl_buyingpslot[playerid] = ClothingExistSlot(playerid)) != -1)
		//{
		//	if(!PurchaseClothing(playerid))
		//	return SendServerMessage(playerid, "This item can not be purchased.");
		//}
	}
	if(clickedid == EditingClothingTD[12])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		Dialog_Show(playerid, ClothingBone, DIALOG_STYLE_LIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Change The Bone Slot", "spine\nhead\nUpper left arm\nRight arm\nleft hand\nright hand\nLeft leg\nRight thigh\nLeft foot\nRight foot\nRight calf\nLeft calf\nleft arm\nright arm\nLeft collarbone\nRight collarbone\nneck\njaw", "Select", "<<");
	}
	if(clickedid == EditingClothingTD[15])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_x] + 0.01;

		ClothingData[playerid][id][cl_x] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[16])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;

		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_x] - 0.01;

		ClothingData[playerid][id][cl_x] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[20])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;

		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_y] + 0.01;

		ClothingData[playerid][id][cl_y] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[22])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;

		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_y] - 0.01;

		ClothingData[playerid][id][cl_y] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[25])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_z] + 0.01;

		ClothingData[playerid][id][cl_z] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[27])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_z] - 0.01;

		ClothingData[playerid][id][cl_z] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	//
	if(clickedid == EditingClothingTD[30])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_rx] + 1.5;

		ClothingData[playerid][id][cl_rx] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);

	}
	if(clickedid == EditingClothingTD[32])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_rx] - 1.5;

		ClothingData[playerid][id][cl_rx] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[35])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_ry] + 1.5;

		ClothingData[playerid][id][cl_ry] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[37])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_ry] - 1.5;

		ClothingData[playerid][id][cl_ry] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[40])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_rz] + 1.5;

		ClothingData[playerid][id][cl_rz] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[42])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_rz] - 1.5;

		ClothingData[playerid][id][cl_rz] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[45])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_scalex] + 0.1;

		ClothingData[playerid][id][cl_scalex] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[47])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_scalex] - 0.1;

		ClothingData[playerid][id][cl_scalex] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[50])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_scaley] + 0.1;

		ClothingData[playerid][id][cl_scaley] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[52])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_scaley] - 0.1;

		ClothingData[playerid][id][cl_scaley] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[55])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_scalez] + 0.1;

		ClothingData[playerid][id][cl_scalez] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[57])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];
		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		new Float:clothfinal = ClothingData[playerid][id][cl_scalez] - 0.1;

		ClothingData[playerid][id][cl_scalez] = clothfinal;

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
	}
	if(clickedid == EditingClothingTD[59])
	{
		if(!ClothingData[playerid][cl_dataslot[playerid][cl_selected[playerid]]][cl_object]) return 1;
		new id = cl_dataslot[playerid][cl_selected[playerid]];

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
		ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		EditAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		EditClothing{playerid} = true;
		ShowEditClothingMode(playerid, 0);
	}
	if(clickedid == EditingClothingTD[62])
	{
		SetClothingCameraRight(playerid);
	}
	if(clickedid == EditingClothingTD[63])
	{
		SetClothingCameraLeft(playerid);
	}

	// Walkie Talkie
	if(clickedid == WalkieTalkieTD[6])
	{
		if (PlayerData[playerid][pFrequency] != 0)
		{
			if(ToggleRadio[playerid] == 1)
			{

				CallRemoteFunction("SV_OnPlayerRadio", "ddd", playerid, 0, PlayerData[playerid][pFrequency]);
				SendCustomMessage(playerid, "Info", "Telah keluar dari frekuensi radio.");
				ToggleRadio[playerid] = 0;
			}
			else if(ToggleRadio[playerid] == 0)
			{
				CallRemoteFunction("SV_OnPlayerRadio", "ddd", playerid, 1, PlayerData[playerid][pFrequency]);
				SendCustomMessage(playerid, "Info", "Telah terkoneksi ke radio menggunakan frekuensi (%d Khz)", PlayerData[playerid][pFrequency]);
				ToggleRadio[playerid] = 1;
			}
		}
	}
	if(clickedid == WalkieTalkieTD[7])
	{
		ShowWalkieTalkieTD(playerid, false);
	}
	if(clickedid == WalkieTalkieTD[8])
	{
		ToggleRadio[playerid] = 1;
		PlayerData[playerid][pFrequency] = FrequencyTemp[playerid];
		PlayerTextDrawSetString(playerid, RadioTD[playerid], sprintf("%d", PlayerData[playerid][pFrequency]));
		SendServerMessage(playerid, "Telah mengubah frekuensi radio ke %d Khz", PlayerData[playerid][pFrequency]);
		CallRemoteFunction("SV_OnPlayerRadio", "ddd", playerid, 1, PlayerData[playerid][pFrequency]);
	}


	// Dealer
	if(clickedid == DealerTD[1])
	{
		if(ViewDealer[playerid])
		{
			if(ViewDealer[playerid])
			{
				SetPlayerVirtualWorld(playerid, (playerid + 1000));
				SetPlayerInterior(playerid, 1);
				InterpolateCameraPos(playerid, 1340.295043, 1577.334228, 3012.926269, 1340.295043, 1577.334228, 3012.926269, 3000, CAMERA_MOVE);
				InterpolateCameraLookAt(playerid, 1344.244873, 1577.232177, 3012.302734, 1344.244873, 1577.232177, 3012.302734, 3000, CAMERA_MOVE);
				TogglePlayerControllable(playerid, false);

				if(ViewingMicksCarID[playerid] != INVALID_VEHICLE_ID)
					DestroyVehicle(ViewingMicksCarID[playerid]), ViewingMicksCarID[playerid] = INVALID_VEHICLE_ID;

				ViewingMicksCar[playerid] -= 1;
				if(ViewingMicksCar[playerid] < 0)
				{
					ViewingMicksCar[playerid] = 0;
				}

				ViewingMicksCarID[playerid] = CreateVehicle(MicksVehicleData[ViewingMicksCar[playerid]][0], 1350.4342,1576.8738,3010.6521,89.9970, -1, -1, 60000); //CarSelection

				new Float:max_veh_killo = GetVehicleMaxKillo(GetVehicleModel(ViewingMicksCarID[playerid]));
				static cstr[500];
				format(cstr, sizeof(cstr), "~y~%s (~p~%0.2f~y~ KG)", GetVehicleNameEx(MicksVehicleData[ViewingMicksCar[playerid]][0]), max_veh_killo);
				PlayerTextDrawSetString(playerid, DealerPTD[playerid][0], cstr);
				PlayerTextDrawSetString(playerid, DealerPTD[playerid][1], sprintf("~g~%s", FormatNumber(MicksVehicleData[ViewingMicksCar[playerid]][1])));

				LinkVehicleToInterior(ViewingMicksCarID[playerid], 1);

				SetVehicleVirtualWorld(ViewingMicksCarID[playerid], (playerid + 1000));
			}
		}
	}
	if(clickedid == DealerTD[4])
	{
		if(ViewDealer[playerid])
		{
			SetPlayerVirtualWorld(playerid, (playerid + 1000));
			SetPlayerInterior(playerid, 1);
			InterpolateCameraPos(playerid, 1340.295043, 1577.334228, 3012.926269, 1340.295043, 1577.334228, 3012.926269, 3000, CAMERA_MOVE);
			InterpolateCameraLookAt(playerid, 1344.244873, 1577.232177, 3012.302734, 1344.244873, 1577.232177, 3012.302734, 3000, CAMERA_MOVE);
			TogglePlayerControllable(playerid, false);

			DestroyVehicle(ViewingMicksCarID[playerid]);
			ViewingMicksCarID[playerid] = INVALID_VEHICLE_ID;

			ViewingMicksCar[playerid] ++;
			if(ViewingMicksCar[playerid] >= sizeof(MicksVehicleData))
			{
				ViewingMicksCar[playerid] = 0;
			}

			ViewingMicksCarID[playerid] = CreateVehicle(MicksVehicleData[ViewingMicksCar[playerid]][0], 1350.4342,1576.8738,3010.6521,89.9970, -1, -1, 60000); //CarSelection
			SetVehicleVirtualWorld(ViewingMicksCarID[playerid], (playerid + 1000));\
			LinkVehicleToInterior(ViewingMicksCarID[playerid], 1);

			new Float:max_veh_killo = GetVehicleMaxKillo(GetVehicleModel(ViewingMicksCarID[playerid]));
			static cstr[500];
			format(cstr, sizeof(cstr), "~y~%s (~p~%0.2f~y~ KG)", GetVehicleNameEx(MicksVehicleData[ViewingMicksCar[playerid]][0]), max_veh_killo);
			PlayerTextDrawSetString(playerid, DealerPTD[playerid][0], cstr);
			PlayerTextDrawSetString(playerid, DealerPTD[playerid][1], sprintf("~g~%s", FormatNumber(MicksVehicleData[ViewingMicksCar[playerid]][1])));

		}
	}
	if(clickedid == DealerTD[11])
	{
		if(Vehicle_GetCount(playerid) >= 4 && PlayerData[playerid][pVIP] == 0)
			return SendErrorMessage(playerid, "Kamu hanya dapat memiliki 4 kendaraan");

		if(Vehicle_GetCount(playerid) >= 4 && PlayerData[playerid][pVIP] == 1)
			return SendErrorMessage(playerid, "Kamu hanya dapat memiliki 5 kendaraan");

		if(Vehicle_GetCount(playerid) >= 5 && PlayerData[playerid][pVIP] == 2)
			return SendErrorMessage(playerid, "Kamu hanya dapat memiliki 6 kendaraan");

		if(Vehicle_GetCount(playerid) >= 6 && PlayerData[playerid][pVIP] == 3)
			return SendErrorMessage(playerid, "Kamu hanya dapat memiliki 7 kendaraan");

		if(MicksVehicleData[ViewingMicksCar[playerid]][1] > GetMoney(playerid)) return SendErrorMessage(playerid, "Uang kamu tidak cukup untuk membeli kendaraan ini");
		new arrayPos = ViewingMicksCar[playerid];

		TakeMoney(playerid, MicksVehicleData[arrayPos][1], sprintf("Membeli mobil: %s dari dealer", GetVehicleNameEx(MicksVehicleData[arrayPos][0])));

		if(ViewingMicksCarID[playerid] != INVALID_VEHICLE_ID)
			DestroyVehicle(ViewingMicksCarID[playerid]), ViewingMicksCarID[playerid] = INVALID_VEHICLE_ID;

		SetPlayerVirtualWorldEx(playerid, 0);
		SetPlayerInteriorEx(playerid, 0);
		SetCameraBehindPlayer(playerid);
		TogglePlayerControllable(playerid, true);

        Vehicle_Create(playerid, PlayerData[playerid][pID], MicksVehicleData[arrayPos][0], 675.03, -1470.93, 15.40,90.61, RandomEx(1, 100), RandomEx(1, 100), true);
		DeletePVar(playerid, "ViewingStock");
		ViewingMicksCar[playerid] = -1;
		ViewingMicksCarID[playerid] = -1;

		ShowPlayerDealer(playerid, false);
	}
	if(clickedid == DealerTD[12])
	{
		ViewDealer[playerid] = 0;
		ShowPlayerDealer(playerid, false);

		DestroyVehicle(ViewingMicksCarID[playerid]);

		ViewingMicksCar[playerid] = -1;
		ViewingMicksCarID[playerid] = INVALID_VEHICLE_ID;

		SetPlayerPos(playerid, 686.28, -1512.75, 15.48);
		SetPlayerVirtualWorldEx(playerid, 0);
		SetPlayerInteriorEx(playerid, 0);
		SetCameraBehindPlayer(playerid);
		TogglePlayerControllable(playerid, true);

	}
	if(clickedid == InventoryTD[8])
	{
		if(PlayerData[playerid][pFrisk])
		{
			PlayerData[playerid][pFrisk] = false;
			//HidePlayerFrisk(playerid);
		}
		else
		{
			ShowInventoryTextdraw(playerid, 0);
			CancelSelectTextDraw(playerid);
		}
	}
	// Inventory
	if(!PlayerData[playerid][pFrisk])
	{
		if(clickedid == InventoryTD[4])
		{
			new
				itemid = PlayerData[playerid][pInventoryItem],
				string[64];

			if(itemid == -1) return SendErrorMessage(playerid, "Kamu belum memilih barang apapun");
			if(!InventoryData[playerid][itemid][invExists]) return SendErrorMessage(playerid, "Barang yang kamu pilih tidak tersedia");

			strunpack(string, InventoryData[playerid][itemid][invItem]);
			Dialog_Show(playerid, DIALOG_AMOUNT, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Amount", "Barang: %s (Jumlah: %d)\n\n"YELLOW"(Silakan masukkan jumlah yang ingin anda give / berikan ke orang:", "Oke", "Back", string, InventoryData[playerid][itemid][invQuantity]);
		}
		if(clickedid == InventoryTD[7])
		{
			new
				itemid = PlayerData[playerid][pInventoryItem],
				id = -1,
				string[64];

			if(PlayerData[playerid][pInventoryItem] == -1) return 0;
			strunpack(string, InventoryData[playerid][itemid][invItem]);

			if (IsPlayerInAnyVehicle(playerid))
				return SendErrorMessage(playerid, "Kamu tidak dapat menjatuhkan item sekarang.");

			if(!strcmp(string, "Phone"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "GPS"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "ID CARD"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "Walkie Talkie"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "Mask"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "Licenses GVL-1"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "Licenses GVL-2"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "Licenses MB"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "Weapon Licenses"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "Money"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			switch (PlayerData[playerid][pStorageSelect])
			{
				case 1:
				{
					if ((id = House_Inside(playerid)) != -1 && House_IsOwner(playerid, id))
					{
						if (InventoryData[playerid][itemid][invQuantity] == 1)
						{
							House_AddItem(id, string, InventoryData[playerid][itemid][invModel], 1);
							Inventory_Remove(playerid, string);

							House_ShowItems(playerid, id);
						}
						else Dialog_Show(playerid, HouseDeposit, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" House Deposit", "Barang: %s (Jumlah: %d)\n\n"YELLOW"(Silakan masukkan jumlah yang ingin Kamu simpan untuk item ini:", "Store", "Back", string, InventoryData[playerid][itemid][invQuantity]);
					}
				}
				case 2:
				{

					if ((id = PlayerData[playerid][pCar]) != -1)
					{
						if (InventoryData[playerid][itemid][invQuantity] == 1)
						{
							if(IsCarStorageFull(id, string, InventoryData[playerid][itemid][invQuantity])) return SendErrorMessage(playerid, "Bagasi kendaraan kamu telah penuh");
							Car_AddItem(id, string, InventoryData[playerid][itemid][invModel], 1);
							Inventory_Remove(playerid, string);

							Car_ShowTrunk(playerid, id);
						}
						else
						{
							new ztr[128];
							format(ztr, sizeof(ztr), "Barang: %s - Jumlah: %d\n\n"YELLOW"Harap tentukan berapa banyak item ini yang ingin Kamu simpan kedalam bagasi:", string, InventoryData[playerid][PlayerData[playerid][pInventoryItem]][invQuantity]);
							Dialog_Show(playerid, DIALOG_TRUNKPUT, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" BAGASI", ztr, "Store", "Back");
						}
					}
				}
				case 3:
				{
					if ((id = PlayerData[playerid][pFaction]) != -1)
					{
						if (InventoryData[playerid][itemid][invQuantity] == 1)
						{
							Faction_AddItem(FactionData[id][factionID], string, InventoryData[playerid][itemid][invModel], 1);
							Inventory_Remove(playerid, string);

							DCC_SendChannelMessage(DCC_Channel:DCC_FindChannelById(GetFactionLockerChannel(GetFactionType(playerid))), sprintf("[%s] - %s(%s) menyimpan %s(%d) ke berangkas", ReturnDate(), ReturnName(playerid), AccountData[playerid][pUsername], string, 1));
						}
						else
						{
							new ztr[128];
							format(ztr, sizeof(ztr), "Barang: %s - Jumlah: %d\n\n"YELLOW"Harap tentukan berapa banyak item ini yang ingin Kamu simpan kedalam berangkas:", string, InventoryData[playerid][PlayerData[playerid][pInventoryItem]][invQuantity]);
							Dialog_Show(playerid, GUDANG_FACTIONPUT, DIALOG_STYLE_INPUT, sprintf("Berangkas", FactionData[id][factionName]), ztr, "Store", "Back");
						}
					}
				}
				case 4:
				{
					if ((id = Flat_Inside(playerid)) != -1 && Flat_IsOwner(playerid, id))
					{
						if(InventoryData[playerid][itemid][invQuantity] == 1)
                    	{
							Room_AddItem(id, string, InventoryData[playerid][itemid][invModel]);
							Inventory_Remove(playerid, string);

							SendActionMessage(playerid, sprintf("has stored a \"%s\" into their room storage.", string));
							Log_Write("logs/storage_log.txt", "[%s] %s has stored \"%s\" into their room ID: %d.", ReturnDate(), ReturnName(playerid, 0), string, id);
                    	}
                    	else
						{
                        	Dialog_Show(playerid, RoomDeposit, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Room Deposit", "Item: %s (Quantity: %d)\n\nPlease enter the quantity that you wish to store for this item:", "Store", "Back", string, InventoryData[playerid][itemid][invQuantity]);
                    	}
					}
				}
				case 5:
				{
					if (InventoryData[playerid][itemid][invQuantity] == 1)
					{
						Warehouse_AddItem(playerid, string, InventoryData[playerid][itemid][invModel], 1);
						Inventory_Remove(playerid, string);

						Warehouse_Show(playerid, playerid);
					}
					else
					{
						new ztr[128];
						format(ztr, sizeof(ztr), "Barang: %s - Jumlah: %d\n\n"YELLOW"Harap tentukan berapa banyak item ini yang ingin Kamu simpan kedalam gudang:", string, InventoryData[playerid][PlayerData[playerid][pInventoryItem]][invQuantity]);
						Dialog_Show(playerid, WarehousePut, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" GUDANG", ztr, "Store", "Back");
					}
				}
				default:
				{
					if (IsPlayerInAnyVehicle(playerid) || !IsPlayerSpawned(playerid))
					{
						return SendErrorMessage(playerid, "Kamu tidak dapat menjatuhkan item sekarang.");
					}
					else if ((id = Garbage_Nearest(playerid)) != -1)
					{
						format(str, sizeof(str), "Barang: %s - Jumlah: %d\n\n"YELLOW"Harap tentukan berapa banyak item ini yang ingin Kamu jatuhkan:", string, InventoryData[playerid][itemid][invQuantity]),
						Dialog_Show(playerid, DIALOG_DROPITEM, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" DROP", str, "Drop", "Cancel");
					}
					else if(InventoryData[playerid][itemid][invQuantity] == 1)
					{
						if(!strcmp(string, "Sampah"))
							return SendErrorMessage(playerid, "Tidak dapat membuang %s sembarangan", string);

						DropPlayerItem(playerid, itemid);
					}
                	else
					{
						if(!strcmp(string, "Sampah"))
							return SendErrorMessage(playerid, "Tidak dapat membuang %s sembarangan", string);

						Dialog_Show(playerid, DropItem, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" DROP", "Barang: %s - Jumlah: %d\n\n"YELLOW"Harap tentukan berapa banyak item ini yang ingin Kamu jatuhkan:", "Drop", "Cancel", string, InventoryData[playerid][itemid][invQuantity]);
					}
				}
			}
		}
		if(clickedid == InventoryTD[5])
		{
			if(PlayerData[playerid][pInventoryItem] == -1 || PlayerData[playerid][pInjured])
				return 0;

			new
				itemid = PlayerData[playerid][pInventoryItem],
				string[64];

			if(InventoryData[playerid][PlayerData[playerid][pInventoryItem]][invQuantity] < 1)
				return SendErrorMessage(playerid, "Tidak ada item di slot yang dipilih!");
			strunpack(string, InventoryData[playerid][itemid][invItem]);

			CallLocalFunction("OnPlayerUseItem", "dds", playerid, itemid, string);
		}
		if(clickedid == InventoryTD[6])
		{
			new
				itemid = PlayerData[playerid][pInventoryItem],
				string[64];

			strunpack(string, InventoryData[playerid][itemid][invItem]);

			if(!strcmp(string, "Phone"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "ID CARD"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "GPS"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "Walkie Talkie"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "Mask"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "Licenses GVL-1"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "Licenses GVL-2"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "Licenses MB"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			if(!strcmp(string, "Weapon Licenses"))
				return SendErrorMessage(playerid, "You cannot do this on this item! (%s)", string);

			PlayerData[playerid][pInventoryItem] = itemid;

			new Float:x,
				Float:y,
				Float:z,
				nearhim[855],
				count;

			GetPlayerPos(playerid, x, y, z);

			foreach(new i : Player) if(PlayerData[i][pLogged] && i != playerid && IsPlayerInRangeOfPoint(i, 2.0, x, y, z)) {
				if(count % 2 == 0) strcat(nearhim, sprintf(""WHITE"Kantong - "YELLOW"%s (%d)\n", ReturnName(i), i));
				else strcat(nearhim, sprintf(""GREY"Kantong - "YELLOW"%s (%d)\n", ReturnName(i), i));
				count ++;
			}
			if(count > 0) Dialog_Show(playerid, INVENTORY_ID, DIALOG_STYLE_LIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Inventory ID", sprintf("%s", nearhim), "Pilih", "Batal");
				else SendErrorMessage(playerid, "Tidak ada orang di sekitar mu");
		}
	}
	
	//newrhenal crating
	new type = PlayerData[playerid][pCraftType];
	
	switch (type)
    {
        case 1: // Cartel
        {
            if (clickedid == Text_Gun[36]) return StartTableCrafting(playerid, WEAP_VEST);
            if (clickedid == Text_Gun[37]) return StartTableCrafting(playerid, WEAP_MARIJUANA);
        }
		case 2: // Mafia
        {
            if (clickedid == Text_Gun[33]) return StartTableCrafting(playerid, WEAP_AK47);
            if (clickedid == Text_Gun[34]) return StartTableCrafting(playerid, WEAP_DEAGLE);
            if (clickedid == Text_Gun[35]) return StartTableCrafting(playerid, WEAP_SHOTGUN);
            if (clickedid == Text_Gun[36]) return StartTableCrafting(playerid, WEAP_MP5);
            if (clickedid == Text_Gun[37]) return StartTableCrafting(playerid, WEAP_SLC);
        }
        case 3: // MC/Biker
        {
            if (clickedid == Text_Gun[36]) return StartTableCrafting(playerid, WEAP_KARUNG);
            if (clickedid == Text_Gun[37]) return StartTableCrafting(playerid, WEAP_TALI);
        }
        case 4: // Gangster
        {
            if (clickedid == Text_Gun[36]) return StartTableCrafting(playerid, WEAP_HACKTOOL);
            if (clickedid == Text_Gun[37]) return StartTableCrafting(playerid, WEAP_LOCKPICK);
            if (clickedid == Text_Gun[38]) return StartTableCrafting(playerid, WEAP_KANABIS);
        }
    }

    if (clickedid == Text_Gun[50]) // CLOSE
    {
        HideCraftingInterface(playerid);
        return SendServerMessage(playerid, "Crafting menu closed.");
    }
	return 1;
}

Function:LC_CancelCall(playerid)
{
	if(PlayerData[playerid][pCallLine] > MAX_PLAYERS) return 0;

	if(IsPlayerConnected(PlayerData[playerid][pCallLine]) && PlayerData[playerid][pCallLine] != INVALID_PLAYER_ID)
	{
		KillTimer(PlayerData[playerid][pCallTimer]);
		KillTimer(PlayerData[PlayerData[playerid][pCallLine]][pCallTimer]);

		ShowPlayerPhone(PlayerData[playerid][pCallLine], false);
		ShowPlayerPhone(playerid, false);

		PlayerData[playerid][pIncomingCall] = 0;
		PlayerData[PlayerData[playerid][pCallLine]][pIncomingCall] = 0;

		SetPlayerSpecialAction(playerid, SPECIAL_ACTION_STOPUSECELLPHONE);
		SetPlayerSpecialAction(PlayerData[playerid][pCallLine], SPECIAL_ACTION_STOPUSECELLPHONE);

		if(IsPlayerAttachedObjectSlotUsed(playerid, 9)) RemovePlayerAttachedObject(playerid, 9);
		if(IsPlayerAttachedObjectSlotUsed(PlayerData[playerid][pCallLine], 9)) RemovePlayerAttachedObject(PlayerData[playerid][pCallLine], 9);

		PlayerData[PlayerData[playerid][pCallLine]][pCallLine] = INVALID_PLAYER_ID;
		PlayerData[playerid][pCallLine] = INVALID_PLAYER_ID;

		PlayerData[PlayerData[playerid][pCallLine]][pCallLine] = INVALID_PLAYER_ID;
		PlayerData[playerid][pCallLine] = INVALID_PLAYER_ID;
	}
	return 1;
}

Function:SetPlayerPhone(playerid)
{
	return CallRemoteFunction("SV_OnPlayerPhone", "ddd", playerid, PlayerData[playerid][pCallLine], PhoneFreq[playerid]);
}

public OnPlayerClickPlayerTextDraw(playerid, PlayerText:playertextid)
{
	#if defined DEBUG_MODE
	    printf("[debug] OnPlayerClickPlayerTextDraw(PID : %d)", playerid);
	#endif

	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(PlayerData[playerid][pInventory])
	{
		forex(i, MAX_INVENTORY)
		{
			if(INVMODEL[playerid][i] != PlayerText:-1)
			{
				if(playertextid == INVMODEL[playerid][i])
				{ 
					if(InventoryData[playerid][i][invExists])
					{
						new before = PlayerData[playerid][pInventoryItem];

						PlayerData[playerid][pInventoryItem] = i;

						PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);

						if(before != -1)
						{
							forex(txd, MAX_INVENTORY)
							{
								PlayerTextDrawColor(playerid, ITEM[playerid][txd], 125);
							}
							PlayerTextDrawColor(playerid, ITEM[playerid][i], -7232257);

							PlayerTextDrawHide(playerid, ITEM[playerid][before]);
							PlayerTextDrawHide(playerid, ITEM[playerid][i]);


							defer RefrestItemTextdraw(playerid, before, i);
						}
					}
					else
					{
						if(AccountData[playerid][pInventoryItem] != -1)
						{
							ItemSwitch(playerid, AccountData[playerid][pInventoryItem], i);
						}
					}
				}
			}
		}
	}
	if(playertextid == RadioTD[playerid])
	{
		Dialog_Show(playerid, DIALOG_FREQUENCY, DIALOG_STYLE_INPUT, ""WHITE""SERVER_NAME" "SERVER_LOGO" Walkie Talkie", "Masukan frequency yang ingin kamu masuki di bawah ini: ", "Pilih", "Batal");
	}
	return 1;
}

stock Float:GetPlayerDistanceFromPlayer(playerid, targetid)
{
	new
	    Float:x,
	    Float:y,
	    Float:z;

	GetPlayerPos(targetid, x, y, z);
	return GetPlayerDistanceFromPoint(playerid, x, y, z);
}

stock IsBleedableWeapon(weaponid)
{
	switch (weaponid) {
	    case 4, 8, 9, 22..38: return 1;
	}
	return 0;
}

public OnPlayerGiveDamage(playerid, damagedid, Float:amount, weaponid, bodypart)
{
	#if defined DEBUG_MODE
	    printf("[debug] OnPlayerGiveDamage(PID : %d TID : %d Amount : %.2f WID : %d Body-Part : %d)", playerid, damagedid, amount, weaponid, bodypart);
	#endif

	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(GetPVarInt(playerid, "IsAtEvent") == 0)
	{
		if(damagedid != INVALID_PLAYER_ID && weaponid == WEAPON_CHAINSAW) {
			TogglePlayerControllable(playerid, false);
			SetPlayerArmedWeapon(playerid, WEAPON_FIST);
			TogglePlayerControllable(playerid, true);
			SetCameraBehindPlayer(playerid);

			SetPVarInt(playerid, "ChainsawWarning", GetPVarInt(playerid, "ChainsawWarning")+1);

			if(GetPVarInt(playerid, "ChainsawWarning") == 3) {
				va_SendClientMessage(playerid, X11_LIGHTBLUE,"[AdmCmd] "RED"%s"LIGHTBLUE" was kicked by BOT. Reason: Abusing Chainsaw", ReturnName(playerid, 0));
				DeletePVar(playerid, "ChainsawWarning");
				KickEx(playerid);
			}
		}
		else if(damagedid != INVALID_PLAYER_ID)
		{
			if((GetFactionType(playerid) == FACTION_POLICE) && PlayerData[playerid][pTazer] && !PlayerData[damagedid][pTazed] && weaponid == 23)
			{
				if(GetPlayerState(damagedid) != PLAYER_STATE_ONFOOT)
					return SendErrorMessage(playerid, "Pemain harus berjalan kaki untuk di tazer.");

				defer UnTazer(damagedid);
				TogglePlayerControllable(damagedid, false);
				PlayerData[damagedid][pTazed] = true;

				ApplyAnimation(damagedid, "CRACK", "crckdeth4", 4.0, false, false, false, true, 0, true);
				SendServerMessage(damagedid, "You have been in Tazer by ~y~%s", ReturnName(playerid));
			}
		}
	}
    return 1;
}

#include "Modules/Player/Hotkey.pwn"


stock IsShotgun(weaponid)
{
	switch(weaponid)
	{
		case 25..27: return true;
		default: return false;
	}
	return false;
}

public OnPlayerTakeDamage(playerid, issuerid, Float:amount, weaponid, bodypart)
{
	#if defined DEBUG_MODE
	    printf("[debug] OnPlayerTakeDamage(PID %d : TID : %d Amount : %.2f WID : %d BodyPart : %d)", playerid, issuerid, amount, weaponid, bodypart);
	#endif

	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(GetPVarInt(playerid, "IsAtEvent") == 0)
	{
		new
			Float:armour = GetArmour(playerid),
			Float:health = GetHealth(playerid);

		if(PlayerData[playerid][pSpawned])
		{
			if(issuerid == INVALID_PLAYER_ID)
			{
				SetHealth(playerid, health-amount);
			}
			if(issuerid != INVALID_PLAYER_ID && !PlayerData[issuerid][pInjured] && !PlayerData[issuerid][pTazed] && BODY_PART_TORSO <= bodypart <= BODY_PART_HEAD)
			{
				if(weaponid >= 0  && weaponid <= 8 && armour >= 0)
				{
					SetHealth(playerid, health-amount);
				}
				else if(22 <= weaponid <= 46)
				{
					if(bodypart == BODY_PART_TORSO && armour > 0.0 && (22 <= weaponid <= 38))
					{
						if(armour - amount <= 7.0)
							SetArmour(playerid, 0.0);
						else
							SetArmour(playerid, armour-amount);
					}
					else
					{
						if(armour > 0.0)
						{
							SetArmour(playerid, armour-amount);
						}
						else
						{
							SetHealth(playerid, health-amount);
						}
					}
				}

				if(weaponid >= 22 && weaponid <= 38)
					Damage_Add(playerid, weaponid, bodypart);
			}

			if(PlayerData[playerid][pAdminDuty] && PlayerData[playerid][pAdmin] > 7)
			{
				SetHealth(playerid, 100);
			}
			PlayerData[playerid][pKiller] = issuerid;
			PlayerData[playerid][pKillerReason] = weaponid;
		}
	}
    return 1;
}

public OnPlayerShootDynamicObject(playerid, weaponid, STREAMER_TAG_OBJECT:objectid, Float:x, Float:y, Float:z)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(GetPlayerInterior(playerid) == 0 && GetPlayerVirtualWorld(playerid) == 0 && !SendTENCODE[playerid] && !Inventory_HasItem(playerid, "Weapon Licenses") && GetFactionType(playerid) != FACTION_POLICE) {
		SendFactionMessageEx(FACTION_POLICE, X11_LIGHT_YELLOW, "Dispatch: Reporting for CODE 10-10 doing 10-20 [%s].", GetPlayerLocation(playerid));
		SendTENCODE[playerid] = true;
	}
	if(SQL_IsCharacterLogged(playerid))
	{
		if (GetPVarInt(playerid, "IsAtEvent") == 0)
		{
			if(GetWeapon(playerid) == weaponid)
			{
				new slot = g_aWeaponSlots[weaponid];

				if(--PlayerData[playerid][pAmmo][slot] <= 0) {
					HoldWeapon(playerid, weaponid);
					ResetWeapon(playerid, weaponid);

					ShowPlayerFooter(playerid, sprintf("Press ~r~H~w~ to reload ~y~%s.", ReturnWeaponName(weaponid)), 3000);
				}
			}
			if (weaponid == 23 && PlayerData[playerid][pTazer] && GetFactionType(playerid) == FACTION_POLICE) {
				PlayerPlaySoundEx(playerid, 6003);
			}
		}
	}
	new animalid = Streamer_GetIntData(STREAMER_TYPE_OBJECT, objectid, E_STREAMER_EXTRA_ID);
    if(0 <= animalid < MAX_DYNAMIC_ANIMAL)
    {
        if(GetWeapon(playerid) >= 22 && AnimalData[animalid][animalObject] == objectid && !AnimalData[animalid][animalGut])
        {
            if(AnimalData[animalid][animalHealth] > 0)
            {
                AnimalData[animalid][animalHealth] -= 50;
            }
            else if(AnimalData[animalid][animalHealth] <= 0)
            {
                AnimalData[animalid][animalHealth] = 0;
                if(AnimalData[animalid][animalModel] == ANIMAL_COW)
                {
                    MoveDynamicObject(AnimalData[animalid][animalObject], AnimalData[animalid][animalPos][0], AnimalData[animalid][animalPos][1], AnimalData[animalid][animalPos][2] - 1.0, 0.025, AnimalData[animalid][animalRot][0], AnimalData[animalid][animalRot][1] - 80.0, RandomFloat(0.0,360.0) + AnimalData[animalid][animalRot][2]);
                }
                else
                {
                    MoveDynamicObject(AnimalData[animalid][animalObject], AnimalData[animalid][animalPos][0], AnimalData[animalid][animalPos][1], AnimalData[animalid][animalPos][2] - 1.0, 0.025, AnimalData[animalid][animalRot][0] - 80.0, AnimalData[animalid][animalRot][1], RandomFloat(0.0,360.0) + AnimalData[animalid][animalRot][2]);
                }
                AnimalData[animalid][animalGut]      = true;
                Animal_Save(animalid, SAVE_HUNTING_GUTTING);
            }
        }
    }
	return 1;
}

public OnPlayerWeaponShot(playerid, weaponid, hittype, hitid, Float:fX, Float:fY, Float:fZ)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(GetPlayerInterior(playerid) == 0 && GetPlayerVirtualWorld(playerid) == 0 && !SendTENCODE[playerid] && !Inventory_HasItem(playerid, "Weapon Licenses") && GetFactionType(playerid) != FACTION_POLICE) 
	{
		SendFactionMessageEx(FACTION_POLICE, X11_LIGHT_YELLOW, "Dispatch: Reporting for CODE 10-10 doing 10-20 [%s].", GetPlayerLocation(playerid));
		SendTENCODE[playerid] = true;

		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid, x, y, z);

		PlayerBlip[playerid] = CreateDynamicMapIcon(x, y, z, 56, -1, 0, 0, -1, 500.0);

		foreach(new i : Player)
		{
			if(GetFactionType(i) == FACTION_POLICE && IsPlayerConnected(i))
			{
				Streamer_AppendArrayData(STREAMER_TYPE_MAP_ICON, PlayerBlip[playerid], E_STREAMER_PLAYER_ID, i);
			}
		}

		SetTimerEx("RemovePlayerBlip", 60000, false, "d", playerid);
	}
	if (GetPVarInt(playerid, "IsAtEvent") == 0)
	{
		if(GetWeapon(playerid) == weaponid)
		{
			new slot = g_aWeaponSlots[weaponid];

			if(--PlayerData[playerid][pAmmo][slot] <= 0) {
				HoldWeapon(playerid, weaponid);
				ResetWeapon(playerid, weaponid);
			}
		}
		if (weaponid == 23 && PlayerData[playerid][pTazer] && GetFactionType(playerid) == FACTION_POLICE) {
			PlayerPlaySoundEx(playerid, 6003);
		}
	}

	return 1;
}

forward RemovePlayerBlip(playerid);
public RemovePlayerBlip(playerid)
{
    if(PlayerBlip[playerid] != -1)
    {
        DestroyDynamicMapIcon(PlayerBlip[playerid]);
        PlayerBlip[playerid] = -1;
    }
}

ResetEditing(playerid)
{
    switch(PlayerData[playerid][pEditingMode])
    {
        case FURNITURE: {
            if(PlayerData[playerid][pEditFurniture] != -1) {
                Furniture_Update(PlayerData[playerid][pEditFurniture]);
                PlayerData[playerid][pEditFurniture] = -1;
            }
        }
        case ROADBLOCK:
        {
            if(PlayerData[playerid][pEditRoadblock] != -1)
            {
                Barricade_Sync(PlayerData[playerid][pEditRoadblock]);
                PlayerData[playerid][pEditRoadblock] = -1;
            }
        }
    }
    PlayerData[playerid][pEditingMode] = NOTHING;
    return 1;
}

public OnPlayerEditDynamicObject(playerid, objectid, response, Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz)
{
	#if defined DEBUG_MODE
	    printf("[debug] OnPlayerEditDynamicObject(PID : %d OID : %d Response : %d X : %f Y : %f Z : %f RX : %f RY : %f RZ : %f)", playerid, objectid, response, x, y, z, rx, ry, rz);
	#endif

	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	new Float:oldX, Float:oldY, Float:oldZ, Float:oldRotX, Float:oldRotY, Float:oldRotZ;

	GetDynamicObjectPos(objectid, oldX, oldY, oldZ);
	GetDynamicObjectRot(objectid, oldRotX, oldRotY, oldRotZ);

	if(response == EDIT_RESPONSE_FINAL)
    {
		if (PlayerData[playerid][pVObject] != -1 && PlayerData[playerid][pEditingMode] == VEHICLE)
		{

			new id = PlayerData[playerid][pVObject],
				slot = PlayerData[playerid][pVObjectList];

			if(PlayerTemp[playerid][temp_pivot] != INVALID_STREAMER_ID)
			{
				DestroyDynamicObject(PlayerTemp[playerid][temp_pivot]);
				PlayerTemp[playerid][temp_pivot] = INVALID_STREAMER_ID;
			}

			new Float:v_size[3];
			GetVehicleModelInfo(VehicleData[id][cModel], VEHICLE_MODEL_INFO_SIZE, v_size[0], v_size[1], v_size[2]);

			if	((VehicleObjects[id][slot][object_x] >= v_size[0] || -v_size[0] >= VehicleObjects[id][slot][object_x]) || (VehicleObjects[id][slot][object_y] >= v_size[1] || -v_size[1] >= VehicleObjects[id][slot][object_y]) || (VehicleObjects[id][slot][object_z] >= v_size[2] || -v_size[2] >= VehicleObjects[id][slot][object_z])) {
				SendErrorMessage(playerid, "Posisi object terlalu jauh dari body kendaraan.");
				VehicleObjects[id][slot][object_x] = PlayerTemp[playerid][temp_voldpos][0];
				VehicleObjects[id][slot][object_y] = PlayerTemp[playerid][temp_voldpos][1];
				VehicleObjects[id][slot][object_z] = PlayerTemp[playerid][temp_voldpos][2];
				VehicleObjects[id][slot][object_rx] = PlayerTemp[playerid][temp_voldpos][3];
				VehicleObjects[id][slot][object_ry] = PlayerTemp[playerid][temp_voldpos][4];
				VehicleObjects[id][slot][object_rz] = PlayerTemp[playerid][temp_voldpos][5];
				Vehicle_ObjectUpdate(id, slot);
				Streamer_Update(playerid);
				PlayerData[playerid][pEditingMode] = NOTHING;
				Dialog_Show(playerid, VACCSE, DIALOG_STYLE_LIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Vehicle Accesories > Edit", "%s\nEdit Position\nRemove From Vehicle", "Select", "Back", VehicleObjects[id][slot][object_type] == OBJECT_TYPE_BODY ? ("Set Color") : ("Edit Text"));
				return 1;
			}
			GiveMoney(playerid, -VEHICLE_OBJECT_EDIT_PRICE);
			LogPlayerTransaction(playerid, "(-) OBJECT EDITING", INVALID_PLAYER_ID, VEHICLE_OBJECT_EDIT_PRICE);
			new Float:vpos[3];
			GetVehiclePos(VehicleData[id][cVehicle], vpos[0], vpos[1], vpos[2]);

			VehicleObjects[id][slot][object_x] = x - vpos[0];
			VehicleObjects[id][slot][object_y] = y - vpos[1];
			VehicleObjects[id][slot][object_z] = z - vpos[2];
			VehicleObjects[id][slot][object_rx] = rx;
			VehicleObjects[id][slot][object_ry] = ry;
			VehicleObjects[id][slot][object_rz] = rz;

			Vehicle_ObjectUpdate(id, slot);
			Vehicle_ObjectSave(id, slot);
			Streamer_Update(playerid);
			PlayerData[playerid][pEditingMode] = NOTHING;

			SendServerMessage(playerid, "Your vehicle modifications have been saved.");
			Dialog_Show(playerid, VACCSE, DIALOG_STYLE_LIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Vehicle Accesories > Edit", "%s\nEdit Position\nRemove From Vehicle", "Select", "Back", VehicleObjects[id][slot][object_type] == OBJECT_TYPE_BODY ? ("Set Color") : ("Edit Text"));
		}

		else if((Streamer_GetIntData(STREAMER_TYPE_OBJECT, objectid, E_STREAMER_MODEL_ID) == 2332 || Streamer_GetIntData(STREAMER_TYPE_OBJECT, objectid, E_STREAMER_MODEL_ID) == 1829) && Iter_Contains(Safes, EditingSafeID[playerid]))
		{
            new id = EditingSafeID[playerid];
            SafeData[id][SafeX] = x;
            SafeData[id][SafeY] = y;
			SafeData[id][SafeZ] = z;
			SafeData[id][SafeRot] = rz;

            Streamer_SetFloatData(STREAMER_TYPE_3D_TEXT_LABEL, SafeData[id][SafeLabel], E_STREAMER_X, SafeData[id][SafeX]);
	        Streamer_SetFloatData(STREAMER_TYPE_3D_TEXT_LABEL, SafeData[id][SafeLabel], E_STREAMER_Y, SafeData[id][SafeY]);
	        Streamer_SetFloatData(STREAMER_TYPE_3D_TEXT_LABEL, SafeData[id][SafeLabel], E_STREAMER_Z, SafeData[id][SafeZ] + 0.8);

            SetDynamicObjectPos(objectid, SafeData[id][SafeX], SafeData[id][SafeY], SafeData[id][SafeZ]);
  			SetDynamicObjectRot(objectid, 0.0, 0.0, SafeData[id][SafeRot]);

  			// save to database
			Safe_Save(id);
			Safe_Refresh(id);

            EditingSafeID[playerid] = -1;
		}

		else if (PlayerData[playerid][pEditPump] != -1 && PumpData[PlayerData[playerid][pEditPump]][pumpExists])
	    {
			PumpData[PlayerData[playerid][pEditPump]][pumpPos][0] = x;
			PumpData[PlayerData[playerid][pEditPump]][pumpPos][1] = y;
			PumpData[PlayerData[playerid][pEditPump]][pumpPos][2] = z;
			PumpData[PlayerData[playerid][pEditPump]][pumpPos][3] = rz;

			Pump_Refresh(PlayerData[playerid][pEditPump]);
			Pump_Save(PlayerData[playerid][pEditPump]);

			SendAdminAction(playerid, "Kamu telah mengedit posisi pump ID: %d.", PlayerData[playerid][pEditPump]);

			PlayerData[playerid][pEditPump] = -1;
	    }
		else if (PlayerData[playerid][pEditAtm] != -1 && AtmData[PlayerData[playerid][pEditAtm]][atmExists])
	    {
			AtmData[PlayerData[playerid][pEditAtm]][atmPos][0] = x;
			AtmData[PlayerData[playerid][pEditAtm]][atmPos][1] = y;
			AtmData[PlayerData[playerid][pEditAtm]][atmPos][2] = z;
			AtmData[PlayerData[playerid][pEditAtm]][atmPos][3] = rz;

			ATM_Refresh(PlayerData[playerid][pEditAtm]);
			ATM_Save(PlayerData[playerid][pEditAtm]);

			SendAdminAction(playerid, "Kamu telah mengedit posisi atm ID: %d.", PlayerData[playerid][pEditAtm]);

			PlayerData[playerid][pEditAtm] = -1;
	    }
		else if(EditWeedPlant[playerid] != -1)
		{
			new id = EditWeedPlant[playerid];

			WeedData[id][WeedPos][0] = x;
			WeedData[id][WeedPos][1] = y;
			WeedData[id][WeedPos][2] = z;
			WeedData[id][WeedRot][0] = rx;
			WeedData[id][WeedRot][1] = ry;
			WeedData[id][WeedRot][2] = rz;

			SetDynamicObjectPos(objectid,x,y,z);
			SetDynamicObjectRot(objectid,rx,ry,rz);
			Weed_Refresh(id);
			Weed_Save(id);

			EditWeedPlant[playerid] = -1;
			SendCustomMessage(playerid,"Plant","Weed position has been saved.");
		}
		else if(GetPVarInt(playerid, "EditingMoveDoor") == 1)
		{
			new i = GetPVarInt(playerid, "ObjectEditing");

			if(Iter_Contains(Movedoors, i))
			{
				Doors[i][doorPosX] = x;
	      		Doors[i][doorPosY] = y;
	      		Doors[i][doorPosZ] = z;
	      		Doors[i][doorPosRX] = rx;
	      		Doors[i][doorPosRY] = ry;
	      		Doors[i][doorPosRZ] = rz;

				SetDynamicObjectPos(objectid, x, y, z);
				SetDynamicObjectRot(objectid, rx, ry, rz);

				va_SendClientMessage(playerid, COLOR_YELLOW, "Moving door %d's default position adjusted to: %f, %f, %f", x, y, z);

				SaveEditedMoveDoor(i, x, y, z, rx, ry, rz);

				DeletePVar(playerid, "EditingMoveDoor");
				DeletePVar(playerid, "ObjectEditing");
			}
		}
		else if(GetPVarInt(playerid, "EditingMoveDoorMove") == 1)
		{
			new i = GetPVarInt(playerid, "ObjectEditing");

			if(Iter_Contains(Movedoors, i))
			{
				if(response == EDIT_RESPONSE_FINAL)
				{
					Doors[i][doorMoveX] = x;
					Doors[i][doorMoveY] = y;
					Doors[i][doorMoveZ] = z;
					Doors[i][doorMoveRX] = rx;
					Doors[i][doorMoveRY] = ry;
					Doors[i][doorMoveRZ] = rz;

					SetDynamicObjectPos(objectid, oldX, oldY, oldZ);
					SetDynamicObjectRot(objectid, oldRotX, oldRotY, oldRotZ);

					va_SendClientMessage(playerid, COLOR_YELLOW, "Moving door %d's moving position adjusted to: %f, %f, %f", x, y, z);

					SaveEditedMoveDoorMove(i, x, y, z, rx, ry, rz);

					DeletePVar(playerid, "EditingMoveDoorMove");
					DeletePVar(playerid, "ObjectEditing");
				}
				else if(response == EDIT_RESPONSE_CANCEL)
				{
					SetDynamicObjectPos(objectid, oldX, oldY, oldZ);
					SetDynamicObjectRot(objectid, oldRotX, oldRotY, oldRotZ);

					va_SendClientMessage(playerid, COLOR_YELLOW, "You're no longer editing the moving door.");

					DeletePVar(playerid, "EditingMoveDoorMove");
					DeletePVar(playerid, "ObjectEditing");
				}
			}
		}
		else if(GetPVarInt(playerid, "EditingGate") == 1)
		{
			new i = GetPVarInt(playerid, "ObjectEditing");

			if(objectid == Gates[i][gateObject] && Iter_Contains(Gates, i))
			{

	      		Gates[i][gatePosX] = x;
	      		Gates[i][gatePosY] = y;
	      		Gates[i][gatePosZ] = z;
	      		Gates[i][gatePosRX] = rx;
	      		Gates[i][gatePosRY] = ry;
	      		Gates[i][gatePosRZ] = rz;

				SetDynamicObjectPos(objectid, x, y, z);
				SetDynamicObjectRot(objectid, rx, ry, rz);

				va_SendClientMessage(playerid, COLOR_YELLOW, "You've successfully set Gate %d's default position to: %f, %f, %f", i, x, y, z);

				SaveEditedGate(i, x, y, z, rx, ry, rz);

				DeletePVar(playerid, "EditingGate");
				DeletePVar(playerid, "ObjectEditing");
			}
		}
		else if(GetPVarInt(playerid, "EditingGateMove") == 1)
		{
	    	new i = GetPVarInt(playerid, "ObjectEditing");

			if(objectid == Gates[i][gateObject] && Iter_Contains(Gates, i))
			{
	      		Gates[i][gateMoveX] = x;
	      		Gates[i][gateMoveY] = y;
	      		Gates[i][gateMoveZ] = z;

	      		Gates[i][gateMoveRX] = rx;
	      		Gates[i][gateMoveRY] = ry;
	      		Gates[i][gateMoveRZ] = rz;

				SetDynamicObjectPos(objectid, oldX, oldY, oldZ);
				SetDynamicObjectRot(objectid, oldRotX, oldRotY, oldRotZ);

				va_SendClientMessage(playerid, COLOR_YELLOW, "You've successfully set Gate %d's moving position to: %f, %f, %f", i, x, y, z);

				SaveEditedGateMove(i, x, y, z, rx, ry, rz);

				DeletePVar(playerid, "EditingGateMove");
				DeletePVar(playerid, "ObjectEditing");
			}
		}
		switch(PlayerData[playerid][pEditingMode])
		{
			 case OBJECT: {
                if(PlayerData[playerid][pEditObject] != -1 && Iter_Contains(Obj, PlayerData[playerid][pEditObject]) && PlayerData[playerid][pEditingMode] == OBJECT) {
                    new id = PlayerData[playerid][pEditObject];
                    ObjData[id][oPos][0] = x;
                    ObjData[id][oPos][1] = y;
                    ObjData[id][oPos][2] = z;
                    ObjData[id][oRot][0] = rx;
                    ObjData[id][oRot][1] = ry;
                    ObjData[id][oRot][2] = rz;

                    SetDynamicObjectPos(objectid,x,y,z);
                    SetDynamicObjectRot(objectid,rx,ry,rz);

                    Object_Refresh(id);
                    Object_Save(id);
                    Object_Update3DText(playerid, id);
                    SendCustomMessage(playerid, "Object", "You've successfully edited object id: %d", id);
                    PlayerData[playerid][pEditObject] = -1;
                    Streamer_Update(playerid);
                }
            }
			case ROADBLOCK:
			{
				new index = PlayerData[playerid][pEditRoadblock];
				BarricadeData[index][cadePos][0] = x;
				BarricadeData[index][cadePos][1] = y;
				BarricadeData[index][cadePos][2] = z;
				BarricadeData[index][cadePos][3] = rx;
				BarricadeData[index][cadePos][4] = ry;
				BarricadeData[index][cadePos][5] = rz;
				Barricade_Sync(index);
				PlayerData[playerid][pEditRoadblock] = -1;
			}
			case FURNITURE:
			{
                if(PlayerData[playerid][pEditFurniture] != -1 && FurnitureData[PlayerData[playerid][pEditFurniture]][furnitureExists] && PlayerData[playerid][pEditingMode] == FURNITURE)
                {
                    new id = House_Inside(playerid);
                    if(id != -1 && House_IsOwner(playerid, id))
                    {
                        FurnitureData[PlayerData[playerid][pEditFurniture]][furniturePos][0] = x;
                        FurnitureData[PlayerData[playerid][pEditFurniture]][furniturePos][1] = y;
                        FurnitureData[PlayerData[playerid][pEditFurniture]][furniturePos][2] = z;
                        FurnitureData[PlayerData[playerid][pEditFurniture]][furnitureRot][0] = rx;
                        FurnitureData[PlayerData[playerid][pEditFurniture]][furnitureRot][1] = ry;
                        FurnitureData[PlayerData[playerid][pEditFurniture]][furnitureRot][2] = rz;

                        Furniture_Update(PlayerData[playerid][pEditFurniture]);
                        Furniture_Save(PlayerData[playerid][pEditFurniture]);

                        ShowPlayerFooter(playerid, sprintf("Kamu telah mengatur posisi ~b~%s", FurnitureData[PlayerData[playerid][pEditFurniture]][furnitureName]), 3000);

                        PlayerData[playerid][pEditFurniture] = -1;
                    }
                }
            }
        }
        ResetEditing(playerid);
	}
	if(response == EDIT_RESPONSE_CANCEL)
    {
		switch(PlayerData[playerid][pEditingMode])
		{
			case OBJECT:
			{
				new Float:position[3],Float:rotation[3];
				if(PlayerData[playerid][pEditObject] != -1)
				{
					new slot = PlayerData[playerid][pEditObject];
					Streamer_GetFloatData(STREAMER_TYPE_OBJECT,ObjData[slot][oObject],E_STREAMER_X,position[0]);
					Streamer_GetFloatData(STREAMER_TYPE_OBJECT,ObjData[slot][oObject],E_STREAMER_Y,position[1]);
					Streamer_GetFloatData(STREAMER_TYPE_OBJECT,ObjData[slot][oObject],E_STREAMER_Z,position[2]);
					Streamer_GetFloatData(STREAMER_TYPE_OBJECT,ObjData[slot][oObject],E_STREAMER_R_X,rotation[0]);
					Streamer_GetFloatData(STREAMER_TYPE_OBJECT,ObjData[slot][oObject],E_STREAMER_R_Y,rotation[1]);
					Streamer_GetFloatData(STREAMER_TYPE_OBJECT,ObjData[slot][oObject],E_STREAMER_R_Z,rotation[2]);
					SetDynamicObjectPos(objectid,position[0],position[1],position[2]);
					SetDynamicObjectRot(objectid,rotation[0],rotation[1],rotation[2]);
				}
			}
		}

		if (PlayerData[playerid][pVObject] != -1 && PlayerData[playerid][pEditingMode] == VEHICLE)
		{
			new id = PlayerData[playerid][pVObject],
				slot = PlayerData[playerid][pVObjectList];

			if(PlayerTemp[playerid][temp_pivot] != INVALID_STREAMER_ID)
			{
				DestroyDynamicObject(PlayerTemp[playerid][temp_pivot]);
				PlayerTemp[playerid][temp_pivot] = INVALID_STREAMER_ID;
			}
			VehicleObjects[id][slot][object_x] = PlayerTemp[playerid][temp_voldpos][0];
			VehicleObjects[id][slot][object_y] = PlayerTemp[playerid][temp_voldpos][1];
			VehicleObjects[id][slot][object_z] = PlayerTemp[playerid][temp_voldpos][2];
			VehicleObjects[id][slot][object_rx] = PlayerTemp[playerid][temp_voldpos][3];
			VehicleObjects[id][slot][object_ry] = PlayerTemp[playerid][temp_voldpos][4];
			VehicleObjects[id][slot][object_rz] = PlayerTemp[playerid][temp_voldpos][5];
			Vehicle_ObjectUpdate(id, slot);
			Streamer_Update(playerid);
			PlayerData[playerid][pEditingMode] = NOTHING;
			SendServerMessage(playerid, "You have ~r~canceled~w~ editing modifications.");
			Dialog_Show(playerid, VACCSE, DIALOG_STYLE_LIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Vehicle Accesories > Edit", "%s\nEdit Position\nRemove From Vehicle", "Select", "Back", VehicleObjects[id][slot][object_type] == OBJECT_TYPE_BODY ? ("Set Color") : ("Edit Text"));
		}
		else if((Streamer_GetIntData(STREAMER_TYPE_OBJECT, objectid, E_STREAMER_MODEL_ID) == 2332 || Streamer_GetIntData(STREAMER_TYPE_OBJECT, objectid, E_STREAMER_MODEL_ID) == 1829) && Iter_Contains(Safes, EditingSafeID[playerid]))
		{
			new id = EditingSafeID[playerid];
			SetDynamicObjectPos(objectid, SafeData[id][SafeX], SafeData[id][SafeY], SafeData[id][SafeZ]);
  			SetDynamicObjectRot(objectid, 0.0, 0.0, SafeData[id][SafeRot]);

			EditingSafeID[playerid] = -1;
		}
		else if(EditWeedPlant[playerid] != -1)
		{
			new id = EditWeedPlant[playerid],Float:position[3],Float:rotation[3];

			Streamer_GetFloatData(STREAMER_TYPE_OBJECT,WeedData[id][WeedObject],E_STREAMER_X,position[0]);
			Streamer_GetFloatData(STREAMER_TYPE_OBJECT,WeedData[id][WeedObject],E_STREAMER_Y,position[1]);
			Streamer_GetFloatData(STREAMER_TYPE_OBJECT,WeedData[id][WeedObject],E_STREAMER_Z,position[2]);
			Streamer_GetFloatData(STREAMER_TYPE_OBJECT,WeedData[id][WeedObject],E_STREAMER_R_X,rotation[0]);
			Streamer_GetFloatData(STREAMER_TYPE_OBJECT,WeedData[id][WeedObject],E_STREAMER_R_Y,rotation[1]);
			Streamer_GetFloatData(STREAMER_TYPE_OBJECT,WeedData[id][WeedObject],E_STREAMER_R_Z,rotation[2]);
			SetDynamicObjectPos(objectid,position[0],position[1],position[2]);
			SetDynamicObjectRot(objectid,rotation[0],rotation[1],rotation[2]);

			EditWeedPlant[playerid] = -1;
			SendServerMessage(playerid, "You've ~r~canceled~w~ editing weed.");
		}
		else if(GetPVarInt(playerid, "EditingMoveDoor") == 1)
		{
			new i = GetPVarInt(playerid, "ObjectEditing");

			if(Iter_Contains(Movedoors, i))
			{
				SetDynamicObjectPos(objectid, oldX, oldY, oldZ);
				SetDynamicObjectRot(objectid, oldRotX, oldRotY, oldRotZ);

				va_SendClientMessage(playerid, COLOR_YELLOW, "You're no longer editing the moving door.");

				DeletePVar(playerid, "EditingMoveDoor");
				DeletePVar(playerid, "ObjectEditing");
			}
		}
		else if(GetPVarInt(playerid, "EditingMoveDoorMove") == 1)
		{
			new i = GetPVarInt(playerid, "ObjectEditing");

			if(Iter_Contains(Movedoors, i))
			{
				SetDynamicObjectPos(objectid, oldX, oldY, oldZ);
				SetDynamicObjectRot(objectid, oldRotX, oldRotY, oldRotZ);

				va_SendClientMessage(playerid, COLOR_YELLOW, "You're no longer editing the moving door.");

				DeletePVar(playerid, "EditingMoveDoorMove");
				DeletePVar(playerid, "ObjectEditing");
			}
		}
		else if(GetPVarInt(playerid, "EditingGate") == 1)
		{
			new i = GetPVarInt(playerid, "ObjectEditing");

			if(objectid == Gates[i][gateObject] && Iter_Contains(Gates, i))
			{
				SetDynamicObjectPos(objectid, oldX, oldY, oldZ);
				SetDynamicObjectRot(objectid, oldRotX, oldRotY, oldRotZ);

				va_SendClientMessage(playerid, COLOR_YELLOW, "You're no longer adjusting Gate %d's default position.", i);

				DeletePVar(playerid, "EditingGate");
				DeletePVar(playerid, "ObjectEditing");
			}
		}
		else if(GetPVarInt(playerid, "EditingGateMove") == 1)
		{
			new i = GetPVarInt(playerid, "ObjectEditing");
			if(objectid == Gates[i][gateObject] && Iter_Contains(Gates, i))
			{
				SetDynamicObjectPos(objectid, oldX, oldY, oldZ);
				SetDynamicObjectRot(objectid, oldRotX, oldRotY, oldRotZ);

				va_SendClientMessage(playerid, COLOR_YELLOW, "You're no longer adjusting Gate %d's moving position.", i);

				DeletePVar(playerid, "EditingGateMove");
				DeletePVar(playerid, "ObjectEditing");
			}
		}
	}
	if(response == EDIT_RESPONSE_CANCEL)
	{
		ResetEditing(playerid);
	}
	if (response == EDIT_RESPONSE_CANCEL || response == EDIT_RESPONSE_FINAL)
	{
		PlayerData[playerid][pVObject] = -1;
		PlayerData[playerid][pEditPump] = -1;
		PlayerData[playerid][pEditAtm] = -1;
		EditWeedPlant[playerid] = -1;
		SetPVarInt(playerid, "EditingMoveDoor", 0);
		SetPVarInt(playerid, "EditingGate", 0);
		SetPVarInt(playerid, "EditingGateMove", 0);
	}

	return 1;
}

//forward OnPlayerEditAttachedObject(playerid, EDIT_RESPONSE:response, index, modelid, boneid, Float:fOffsetX, Float:fOffsetY, Float:fOffsetZ, Float:rotationX, Float:rotationY, Float:rotationZ, Float:scaleX, Float:scaleY, Float:scaleZ);

public OnPlayerEditAttachedObject(playerid, response, index, modelid, boneid, Float:fOffsetX, Float:fOffsetY, Float:fOffsetZ, Float:fRotX, Float:fRotY, Float:fRotZ, Float:fScaleX, Float:fScaleY, Float:fScaleZ)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	new id = cl_selected[playerid];
	if(EditClothing{playerid})
	{
		if(response)
		{
			ClothingData[playerid][id][cl_x] = fOffsetX;
			ClothingData[playerid][id][cl_y] = fOffsetY;
			ClothingData[playerid][id][cl_z] = fOffsetZ;
			ClothingData[playerid][id][cl_rx] = fRotX;
			ClothingData[playerid][id][cl_ry] = fRotY;
			ClothingData[playerid][id][cl_rz] = fRotZ;
			ClothingData[playerid][id][cl_scalex] = fScaleX;
			ClothingData[playerid][id][cl_scaley] = fScaleY;
			ClothingData[playerid][id][cl_scalez] = fScaleZ;

		}

		ClearAnimations(playerid);

		if(IsPlayerAttachedObjectSlotUsed(playerid, ClothingData[playerid][id][cl_slot])) RemovePlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot]);

		SetPlayerAttachedObject(playerid, ClothingData[playerid][id][cl_slot], ClothingData[playerid][id][cl_object], ClothingData[playerid][id][cl_bone], ClothingData[playerid][id][cl_x], ClothingData[playerid][id][cl_y],
        ClothingData[playerid][id][cl_z], ClothingData[playerid][id][cl_rx], ClothingData[playerid][id][cl_ry], ClothingData[playerid][id][cl_rz], ClothingData[playerid][id][cl_scalex], ClothingData[playerid][id][cl_scaley], ClothingData[playerid][id][cl_scalez]);

		UpdateClothingTextdraw(playerid);
		SavePlayerClothing(playerid);
		EditClothing{playerid} = false;
		ShowEditClothingMode(playerid, 1);
		SelectTextDraw(playerid, COLOR_LIGHTBLUE);
	}
	new weaponid = EditingWeapon[playerid];

	if (weaponid)
    {
        if (response)
        {
            new enum_index = weaponid - 2, weaponname[18], name[MAX_PLAYER_NAME], string[340];

            GetWeaponName(weaponid, weaponname, sizeof(weaponname));
            GetPlayerName(playerid, name, MAX_PLAYER_NAME);

            WeaponSettings[playerid][enum_index][Position][0] = fOffsetX;
            WeaponSettings[playerid][enum_index][Position][1] = fOffsetY;
            WeaponSettings[playerid][enum_index][Position][2] = fOffsetZ;
            WeaponSettings[playerid][enum_index][Position][3] = fRotX;
            WeaponSettings[playerid][enum_index][Position][4] = fRotY;
            WeaponSettings[playerid][enum_index][Position][5] = fRotZ;

            RemovePlayerAttachedObject(playerid, GetWeaponObjectSlot(weaponid));
            SetPlayerAttachedObject(playerid, GetWeaponObjectSlot(weaponid), GetWeaponModel(weaponid), WeaponSettings[playerid][enum_index][Bone], fOffsetX, fOffsetY, fOffsetZ, fRotX, fRotY, fRotZ, 1.0, 1.0, 1.0);

            SendCustomMessage(playerid, "Weapon", "Attachment weapon {FF0000}%s {FFFFFF}berhasil diupdate.", weaponname);

            mysql_format(g_SQL, string, sizeof(string), "INSERT INTO weaponsettings (Owner, WeaponID, PosX, PosY, PosZ, RotX, RotY, RotZ) VALUES ('%d', %d, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f) ON DUPLICATE KEY UPDATE PosX = VALUES(PosX), PosY = VALUES(PosY), PosZ = VALUES(PosZ), RotX = VALUES(RotX), RotY = VALUES(RotY), RotZ = VALUES(RotZ)", PlayerData[playerid][pID], weaponid, fOffsetX, fOffsetY, fOffsetZ, fRotX, fRotY, fRotZ);
            mysql_tquery(g_SQL, string);
        }
        EditingWeapon[playerid] = 0;
    }
	return 1;
}


public OnPlayerEnterDynamicArea(playerid, areaid)
{
	#if defined DEBUG_MODEb
	    printf("[debug] OnPlayerEnterDynamicArea(PID : %d AreaID : %d)", playerid, areaid);
	#endif

	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

    if(SQL_IsCharacterLogged(playerid))
    {

		if(areaid == AreaData[areaFarmer][0] || areaid == AreaData[areaFarmer][1] || areaid == AreaData[areaFarmer][2])
		{
			GameTextForPlayer(playerid, "~w~Tekan ~y~[Y]~w~ Menanam Tanaman", 5000, 4);
		}
		if(areaid == PlayerButcherVars[playerid][ChickenTakeArea])
		{
			ShowPressButton(playerid, "[Y]Ambil Ayam");
		}
		forex(i, MAX_MINYAK)
		{
			if(areaid == Minyak[i])
			{
				ShowPressButton(playerid, "[Y]Mining Oil", 3000);
			}
		}
		forex(i, MAX_ATM) if(AtmData[i][atmExists])
		{
			if(areaid == AtmData[i][atmArea])
			{
				if(PlayerData[playerid][pAdmin] > 9 && PlayerData[playerid][pAdminDuty])
				{
					ShowPressButton(playerid, sprintf("[Y]Access ATM %d", i), 3000);
				}
				else ShowPressButton(playerid, "[Y]Access ATM", 3000);
			}
		}
		new streamer_info[2];
		Streamer_GetArrayData(STREAMER_TYPE_AREA, areaid, E_STREAMER_EXTRA_ID, streamer_info);


		/*if(streamer_info[0] == ENTRANCE_AREA_INDEX)
		{
			new index = streamer_info[1];
			if(EntranceData[index][entranceExists])
			{
				ShowPressButton(playerid, sprintf("[Y]%s", EntranceData[index][entranceName]), 3000);

			}
		}*/
		if(streamer_info[0] == BIZ_AREA_INDEX)
		{
			new index = streamer_info[1];
			if(BusinessData[index][bizExists])
			{
				if(BusinessData[index][bizType] == 3)
				{
					ShowPressButton(playerid, "[Y]Clothing Store", 3000);
				}
				else
				{
					ShowPressButton(playerid, "[Y]Market", 3000);
				}
			}
		}

		if(streamer_info[0] == GARKOT_AREA_INDEX)
		{
			new index = streamer_info[1];
			if(ParkInfo[index][parkExist])
			{
				ShowPressButton(playerid, "[Y]Public Garage", 3000);
			}
		}

		if(streamer_info[0] == STONE_AREA_INDEX)
		{
			new index = streamer_info[1];
			if(StoneData[index][stoneExists])
			{
				ShowPressButton(playerid, "[Y]Mine Stone", 3000);
			}
		}

		if(streamer_info[0] == BERANGKAS_AREA_INDEX)
		{
			new index = streamer_info[1];
			if(BerangkasData[index][bExists])
			{
				if(PlayerData[playerid][pAdmin] > 9 && PlayerData[playerid][pAdminDuty])
				{
					ShowPressButton(playerid, sprintf("[Y]Private Locker %d", index), 3000);
				}
				else ShowPressButton(playerid, "[Y]Private Locker", 3000);
			}
		}
		if(streamer_info[0] == WEED_AREA_INDEX)
		{
			new index = streamer_info[1];

			if(WeedData[index][WeedAmount] == 1)
			{
				ShowPressButton(playerid, sprintf("[Y]%s",Weed_ReturnName(index)));
			}
		}

		if(streamer_info[0] == SPEED_AREA_INDEX)
		{
			new index = streamer_info[1];

			if(Speed_IsExists(index))
			{
				if(GetPlayerState(playerid) == PLAYER_STATE_DRIVER && IsEngineVehicle(GetPlayerVehicleID(playerid)) && !IsACruiser(GetPlayerVehicleID(playerid)))
				{
					if(GetVehicleSpeed(GetPlayerVehicleID(playerid)) > SpeedData[index][speedMax])
					{
						new Float:x, Float:y, Float:z;
						GetPlayerPos(playerid, x, y, z);

						foreach(new i : Player) if(GetFactionType(i) == FACTION_POLICE && !IsPlayerToggleSpeedTrap(i) && PlayerData[playerid][pOnDuty])
							va_SendClientMessage(i, X11_LIGHT_YELLOW, "Dispatch: Vehicle: [%s], Plate: [%s], Location: [%s], Speed: [%d of %d KM/H], Heading: [%s].", GetVehicleNameByVehicle(GetPlayerVehicleID(playerid)), GetVehicleNumberPlate2(GetPlayerVehicleID(playerid)), GetLocation(x, y, z), floatround(GetVehicleSpeed(GetPlayerVehicleID(playerid))), SpeedData[index][speedMax], ReturnCompass(playerid));

						format(SpeedData[index][speedDetail], 128, "V: %s | P: %s"ORANGE" | S: %d km/h", GetVehicleNameByVehicle(GetPlayerVehicleID(playerid)), GetVehicleNumberPlate2(GetPlayerVehicleID(playerid)), floatround(GetVehicleSpeed(GetPlayerVehicleID(playerid))));
						Speed_Sync(index, true);

						ShowPlayerFooter(playerid, "~r~Kamu telah melewati batas kecepatan!", 3000);
					}
				}
			}
		}
		if(streamer_info[0] == BARRICADE_AREA_INDEX)
		{
			new index = streamer_info[1];

			if(Barricade_IsExists(index) && BarricadeData[index][cadeType] == 1)
			{
				if(GetPlayerState(playerid) == PLAYER_STATE_DRIVER && !IsABicycle(GetPlayerVehicleID(playerid)))
				{
					static tires[4];
					GetVehicleDamageStatus(GetPlayerVehicleID(playerid), tires[0], tires[1], tires[2], tires[3]);

					if(tires[3] != 1111)
					{
						SendServerMessage(playerid, "Tires leak due to traps nails");
						UpdateVehicleDamageStatus(GetPlayerVehicleID(playerid), tires[0], tires[1], tires[2], 1111);
					}
				}
			}
		}
		if(areaid == AreaSantaiZone)
		{
			SendServerMessage(playerid, "Anda memasuki area santai, stress anda akan berkurang secara perlahan.");
		}
	}
    return 1;
}


public OnPlayerLeaveDynamicArea(playerid, areaid)
{
	#if defined DEBUG_MODE
        printf("[Callback: OnPlayerLeaveDynamicArea]: Player ID: %d, Area ID: %d", playerid, areaid);
    #endif

	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(SQL_IsCharacterLogged(playerid))
    {
		new streamer_info[1];
		Streamer_GetArrayData(STREAMER_TYPE_AREA, areaid, E_STREAMER_EXTRA_ID, streamer_info);

		if(streamer_info[0] == LOCATION_AREA_INDEX) {
			HidePressButton(playerid);
		}
		if(streamer_info[0] == ENTRANCE_AREA_INDEX) {
			HidePressButton(playerid);
		}
		if(streamer_info[0] == GARKOT_AREA_INDEX) {
			HidePressButton(playerid);
		}
		if(streamer_info[0] == STONE_AREA_INDEX) {
			HidePressButton(playerid);
		}
		if(streamer_info[0] == BERANGKAS_AREA_INDEX)
		{
			HidePressButton(playerid);
		}
		if(streamer_info[0] == WEED_AREA_INDEX)
		{
			HidePressButton(playerid);
		}
    }
	if(areaid == AreaData[areaMechanic][0])
	{
		if(PlayerData[playerid][pTargetVehicle] != -1)
		{
			if(IsPlayerInAnyVehicle(playerid))
			{
				new modcount = 0;
				if(PendingPaintjob[playerid] != -1) modcount ++;
				for(new x = 0; x < 14; x++) if(ModQueue[playerid][x] >= 1) modcount ++;
				if(modcount != 0 && IsPlayerInAnyVehicle(playerid))
				{
					if(IsValidVehicle(VehicleData[PlayerData[playerid][pTargetVehicle]][cVehicle]))
					{
						new component, v = PlayerData[playerid][pTargetVehicle];
						for(new x = 0; x < 14; x++) //removes pending components from the vehicle and then readds saved mods
						{
							component = GetVehicleComponentInSlot(v, x);
							if(component != 0) RemoveVehicleComponent(v, component);

							if(VehicleData[v][cMod][x] && IsVehicleUpgradeCompatible(VehicleData[v][cModel], VehicleData[v][cMod][x]))
							{
								AddVehicleComponent(VehicleData[v][cVehicle], VehicleData[v][cMod][x]);
							}
							ModQueue[playerid][x] = 0;
						}
						if(PendingPaintjob[playerid] != -1) ChangeVehiclePaintjob(VehicleData[v][cVehicle], 3);
						PendingPaintjob[playerid] = -1;

						if(VehicleData[v][cPaintJob] < 3) ChangeVehiclePaintjob(VehicleData[v][cVehicle], VehicleData[v][cPaintJob]);
						va_SendClientMessage(playerid, X11_LIMEGREEN,"[Vehicle]: "WHITE"Your pending mods have been {FF0000}removed"WHITE" as you did not purchase them.");
					}
				}
			}
		}
	}
	if(areaid == AreaSantaiZone)
	{
		SendServerMessage(playerid, "Anda keluar dari area santai");
	}
	return 1;
}

public OnCustomSelectionResponse(playerid, extraid, modelid, response)
{
    if(response)
    {
        switch(extraid)
        {
			case MODEL_SELECTION_TUNEVELG:
			{
				new vehicleid = PlayerData[playerid][pTargetVehicle];
				AddVehicleComponent(vehicleid, modelid);
				SaveVehicleComponent(vehicleid, modelid);
				SetPlayerStress(playerid, PlayerData[playerid][pStress] + 1.5);
				SendCustomMessage(playerid, "Info", "You have added "YELLOW"%s"WHITE"wheels to this vehicle.", GetWheelName(modelid));
				Inventory_Remove(playerid, "Component", 100);
				ApplyAnimation(playerid, "BOMBER", "BOM_Plant", 4.1, false, false, false, false, 0, true);
				PlayerPlaySound(playerid,1133,0.0,0.0,0.0);
			}
			case MODEL_SELECTION_CLOTHING:
			{
				if(!response)
				{
					ClearAnimations(playerid);
					return 1;
				}

				for(new i; i < sizeof(cl_ZipData); i++)
				{
					if(cl_ZipData[i][e_model] == modelid)
					{
						new slot = i;
						cl_buyslottemp[playerid] = i;

						if((cl_buyingpslot[playerid] = ClothingExistSlot(playerid)) == -1)
							return va_SendClientMessage(playerid, COLOR_LIGHTRED, "This item can not be purchased.");

						if(slot < 0 || slot >= sizeof(cl_ZipData)) return 0;

						BuyClothing{playerid} = true;

						//SetPlayerAttachedObject(playerid, cl_buyingpslot[playerid], model, bone, x, y, z, rx, ry, rz, sx, sy, sz);
						Dialog_Show(playerid, PurchasedClothing, DIALOG_STYLE_MSGBOX, ""WHITE""SERVER_NAME" "SERVER_LOGO" Purchased Clothing", "Apakah kamu yakin ingin membeli accessoris ini?", "Sure", "Close");
						return 1;
					}
				}
			}
		}
	}
	return 1;
}

public OnModelSelectionResponse(playerid, extraid, index, modelid, response)
{
	#if defined DEBUG_MODE
	    printf("[debug] OnModelSelectionResponse(PID : %d ExtraID : %d Index : %d ModelID : %d Response : %d)",playerid, extraid, index, modelid, response);
	#endif

	if((response) && (extraid ==MODEL_SELECTION_VACC))
    {
        new
            id = -1,
            vehicle = GetPlayerVehicleID(playerid);

        if((id = Vehicle_GetID(vehicle)) != -1)
        {
            Vehicle_ObjectAdd(id, modelid, OBJECT_TYPE_BODY);
            Streamer_Update(playerid);
            GiveMoney(playerid, -VEHICLE_OBJECT_PRICE);
            SendServerMessage(playerid, "You have selected ~y~%s~w~ for this vehicle.", Bodypart_Name(modelid));
            return 1;
        }
    }

	/*if((response) && (extraid ==MODEL_SELECTION_TUNEVELG))
	{
		new vehicleid = PlayerData[playerid][pTargetVehicle];
		AddVehicleComponent(vehicleid, modelid);
		SaveVehicleComponent(vehicleid, modelid);
		SetPlayerStress(playerid, PlayerData[playerid][pStress] + 1.5);
		SendServerMessage(playerid, "You have added ~y~%s~w~ wheels to this vehicle.", GetWheelName(modelid));
		Inventory_Remove(playerid, "Component", 100);
		ApplyAnimation(playerid, "BOMBER", "BOM_Plant", 4.1, false, false, false, false, 0, true);
		PlayerPlaySound(playerid,1133,0.0,0.0,0.0);
	}*/
	if((response) && (extraid == MODEL_SELECTION_CLOTHING))
	{
		if(!response)
		{
			ClearAnimations(playerid);
			return 1;
		}
		for(new i; i < sizeof(cl_ZipData); i++)
		{
			if(cl_ZipData[i][e_model] == modelid)
			{
				new slot = i;
				cl_buyslottemp[playerid] = i;

				if((cl_buyingpslot[playerid] = ClothingExistSlot(playerid)) == -1)
					return va_SendClientMessage(playerid, COLOR_LIGHTRED, "This item can not be purchased.");

				if(slot < 0 || slot >= sizeof(cl_ZipData)) return 0;
				BuyClothing{playerid} = true;
				//SetPlayerAttachedObject(playerid, cl_buyingpslot[playerid], model, bone, x, y, z, rx, ry, rz, sx, sy, sz);
				Dialog_Show(playerid, PurchasedClothing, DIALOG_STYLE_MSGBOX, ""WHITE""SERVER_NAME" "SERVER_LOGO" Purchased Clothing", "Apakah kamu yakin ingin membeli accessoris ini?", "Sure", "Close");
				return 1;
			}
		}
	}
	if(extraid == MODEL_SELECTION_BUYSKIN)
	{
		if(response)
		{
			//benerin nanti  ini bugnya bisnis 
			new businessid = Business_Nearest(playerid, 5.0);
	        TakeMoney(playerid,PlayerData[playerid][pSkinPrice]);
			SendServerMessage(playerid, "Has bought skin from a clothing store.", 3000);
			BusinessData[businessid][bizProducts]--;
			BusinessData[businessid][bizVault] += PlayerData[playerid][pSkinPrice];
			UpdatePlayerSkin(playerid, modelid);
		}
	}
	if((response) && (extraid == MODEL_SELECTION_FURNITURE))
    {
        new
            id = Business_Inside(playerid),
            type = PlayerData[playerid][pFurnitureType],
            price;

        if(id != -1 && BusinessData[id][bizExists] && BusinessData[id][bizType] == 7)
        {
            price = BusinessData[id][bizPrices][type];

            if(GetMoney(playerid) < price)
                return SendErrorMessage(playerid, "You have insufficient funds for the purchase.");

            if(BusinessData[id][bizProducts] < 1)
                return SendErrorMessage(playerid, "This business is out of stock.");

            if(!House_GetCount(playerid))
                return SendErrorMessage(playerid, "You don't have house.");

            new
                str[128],
                count = 0;

            for(new i = 0; i < MAX_HOUSES; i++)
            {
                if(HouseData[i][houseExists] && House_IsOwner(playerid, i))
                {
                    // SendServerMessage(playerid, "ListedHouse %d: %d", count, i);

                    format(str, sizeof(str), "%sHouse Address: %s | Loc: %s\n", str, HouseData[i][houseAddress], GetLocation(HouseData[i][housePos][0], HouseData[i][housePos][1], HouseData[i][housePos][2]));
                    ListedHouse[playerid][count++] = i;
                }

            }
            Dialog_Show(playerid, SelectHouse, DIALOG_STYLE_LIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Select House", str, "Select", "Close");
            SetPVarInt(playerid, "InsideBusiness", id);
            SetPVarInt(playerid, "FurnitureModel", modelid);
            SetPVarInt(playerid, "FurniturePrice", price);
        }
    }
	if((response) && (extraid == MODEL_SELECTION_MODS))
	{
		AddVehicleComponent(VehicleData[PlayerData[playerid][pTargetVehicle]][cVehicle], modelid);

		ModQueue[playerid][GetVehicleComponentType(modelid)] = modelid;
		SendCustomMessage(playerid, "Vehicle", "You have added a(n) "YELLOW"%s"WHITE" to your modding queue. use '"YELLOW"/buymods"WHITE"' to confirm", GetVehicleModName(modelid));

		new mods[50], count = 0, desc[50][32];

		if(IsValidVehicle(VehicleData[PlayerData[playerid][pTargetVehicle]][cVehicle]))
		{
			for(new m = 1000; m < 1193; m++)
			{
				if(IsVehicleUpgradeCompatible(VehicleData[PlayerData[playerid][pTargetVehicle]][cModel], m) && IsActualVehicleMod(m))
				{
					format(desc[count], 32, "%s", GetVehicleModName(m));
					mods[count] = m;
					count ++;
				}
			}
		}
	}
	if((response) && (extraid == MODEL_SELECTION_PARK))
	{
		new vid = ReturnPlayerVehiclePark(playerid, (index + 1), PlayerData[playerid][pPark]);

		GetPlayerPos(playerid, VehicleData[vid][cPos][0], VehicleData[vid][cPos][1], VehicleData[vid][cPos][2]);
		GetPlayerFacingAngle(playerid, VehicleData[vid][cPos][3]);
		GarkotVehicleRespawn(playerid, vid);
		PutPlayerInVehicleEx(playerid, VehicleData[vid][cVehicle], 0);
		SendServerMessage(playerid, "The vehicle was ~y~successfully~w~ taken from the public garage");
	}
	if ((response) && (extraid == MODEL_SELECTION_ADD_SKIN))
	{
	    FactionData[PlayerData[playerid][pFactionEdit]][factionSkins][PlayerData[playerid][pSelectedSlot]] = modelid;
		Faction_Save(PlayerData[playerid][pFactionEdit]);

		SendServerMessage(playerid, "You have set the skin ID in slot ~y~%d ~w~to ~y~%d", PlayerData[playerid][pSelectedSlot], modelid);
	}
	if ((response) && (extraid == MODEL_SELECTION_SKINS))
	{
	    Dialog_Show(playerid, FactionSkin, DIALOG_STYLE_LIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Edit Skin", "Add by Model ID\nAdd by Thumbnail\nClear Slot", "Select", "Cancel");
	    PlayerData[playerid][pSelectedSlot] = index;
	}
	if ((response) && (extraid == MODEL_SELECTION_ADD_SKIN))
	{
	    FactionData[PlayerData[playerid][pFactionEdit]][factionSkins][PlayerData[playerid][pSelectedSlot]] = modelid;
		Faction_Save(PlayerData[playerid][pFactionEdit]);

		SendServerMessage(playerid, "You have set the skin ID in slot ~y~%d ~w~to ~y~%d.", PlayerData[playerid][pSelectedSlot], modelid);
	}
	if ((response) && (extraid == MODEL_SELECTION_FACTION_SKIN))
	{
	    new factionid = PlayerData[playerid][pFaction];

		if (factionid == -1)
	    	return 0;

		if (modelid == 19300)
		    return SendErrorMessage(playerid, "There is no model in the selected slot.");

		if(GetFactionType(playerid) == FACTION_GANG)
		{
			UpdatePlayerSkin(playerid, modelid);
		}
		else
		{
			SetPlayerSkin(playerid, modelid);
			PlayerData[playerid][pFactionSkin] = modelid;
		}
		SendActionMessage(playerid, sprintf( "Has changed their uniform."));
	}
	return 1;
}
public OnPlayerEnterDynamicCP(playerid, STREAMER_TAG_CP:checkpointid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	forex(i, MAX_HOUSES)
	{
		if(checkpointid == HouseData[i][houseCheckpoint])
		{
			if(HouseData[i][houseOwner] != 0)
			{
				if(HouseData[i][houseExists])
				{
					ShowPlayerFooter(playerid, sprintf("~Y~%s~N~~W~Owner: ~G~%s", HouseData[i][houseAddress], GetSQLName(HouseData[i][houseOwner])), 5000, "HOUSES");
				}
			}
			else
			{
				if(HouseData[i][houseExists])
				{
					ShowPlayerFooter(playerid, sprintf("~R~House for sale ~Y~%s~N~~W~Value: ~G~%s~N~~W~To buy use /buy a house", HouseData[i][houseAddress], FormatNumber(HouseData[i][housePrice])), 5000, "HOUSES");
				}
			}
			break;
		}
	}
	for(new i = 0; i != MAX_PLANT; i++)
    {
        if(PlantData[i][PlantExist])
        {
			if(checkpointid == PlantData[i][PlantCP])
			{
				ShowPressButton(playerid, sprintf("[Y]%s", getplantname(PlantData[i][PlantType])), 3000);
				break;
			}
        }
    }
	return 1;
}

public OnPlayerLeaveDynamicCP(playerid, STREAMER_TAG_CP:checkpointid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(IsValidPressButton(playerid)) HidePressButton(playerid);
	return 1;
}

stock GetXYBehindPoint2(&Float:X, &Float:Y, Float:angle, Float:distance)
{
	X -= (distance * floatsin(-angle, degrees));
	Y -= (distance * floatcos(-angle, degrees));
}

public OnPlayerEnterCheckpoint(playerid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	PlayerPlaySound(playerid, SOUND_CHECKPOINT, 0.0, 0.0, 0.0);
	if (Pump_Nearest(playerid) != -1)
	{
		if(PlayerData[playerid][pRefilling])
		{
			new vid = GetNearestVehicle(playerid);

			DisablePlayerCheckpoint(playerid);
			PlayerData[playerid][pRefill] = vid;
			PlayerData[playerid][pRefilling] = 1;

			TogglePlayerControllable(playerid, false);
			ApplyAnimation(playerid, "BD_FIRE", "wash_up", 4.1, true, true, true, false, 0, true);
		}
	}
	return 1;
}

public OnPlayerEnterRaceCheckpoint(playerid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(GetPlayerVehicleID(playerid) == JobVehicle[PlayerData[playerid][pJobVehicle]][Vehicle])
	{
		if(IsPlayerWorkInBus(playerid) && busCounter[playerid] == 1)
		{
			SetBusCheckpointRoute(playerid);
		}
	}
	if(SweeperIndex[playerid] == 11)
	{
		//new money = floatround(SweeperDistance[playerid] * MONEY_PER_METER), string[80];
		DestroyJobVehicle(playerid);

		AddSalary(playerid, "Sweeper Sidejob", 500);
		SendCustomMessage(playerid, "Salary", "You have received a salary of "GREEN"%s"WHITE" as a "YELLOW"sweeper,"WHITE" you can collect this salary at the job center.", FormatNumber(200));

	    ShowPlayerFooter(playerid, sprintf( "~w~Distance Cleaned: ~b~~h~~h~%d Meters ~w~Earned ~g~~h~~h~$%d", 1000*5, 100), 3000, "Sweeper");
	    ResetSweeperInfo(playerid);
		DisablePlayerRaceCheckpoint(playerid);

		PlayerData[playerid][pSweeperStats]++;

		if(PlayerData[playerid][pSweeperStats] == (PlayerData[playerid][pSweeperLevel] * 8))
		{
			PlayerData[playerid][pSweeperLevel] ++;
			SendCustomMessage(playerid, "Job Level", "You are now Sweeper Level %d", PlayerData[playerid][pSweeperLevel]);
		}
		else SendCustomMessage(playerid, "Job Level", "You need %d/%d to go to level %d", PlayerData[playerid][pSweeperStats], (PlayerData[playerid][pSweeperLevel] * 8), PlayerData[playerid][pSweeperLevel] + 1);

		if(PlayerData[playerid][pSweeperLevel] == 1)
		{
			PlayerData[playerid][pSweeperDelay] = 60;
		}
		else if(PlayerData[playerid][pSweeperLevel] == 2)
		{
			PlayerData[playerid][pSweeperDelay] = 55;
		}
		else if(PlayerData[playerid][pSweeperLevel] == 3)
		{
			PlayerData[playerid][pSweeperDelay] = 50;
		}
		else if(PlayerData[playerid][pSweeperLevel] == 4)
		{
			PlayerData[playerid][pSweeperDelay] = 45;
		}
		else if(PlayerData[playerid][pSweeperLevel] == 5)
		{
			PlayerData[playerid][pSweeperDelay] = 40;
		}
	}
	if(DMV_Testing[playerid] > 0 && DMV_Testing[playerid] < 10)
	{
		DMV_Index[playerid] ++;
		DMV_SpeedLimit[playerid] = TestData_Speeds[DMV_Testing[playerid]-1][DMV_Index[playerid]];

		if(DMV_Index[playerid] == DMV_TEST_LAST_CP)
		{
			PassDMVTest(playerid);
			return true;
		}

		new cp_type;

		if(DMV_Index[playerid] < DMV_TEST_LAST_CP - 1)
		{
			switch(DMV_Testing[playerid])
			{
				case 1,2,3,4: cp_type = 0;
				case 5,6: cp_type = 3;
			}
			SetPlayerRaceCheckpointEx(playerid, cp_type, TestData_Points[DMV_Testing[playerid]-1][DMV_Index[playerid]][0], TestData_Points[DMV_Testing[playerid]-1][DMV_Index[playerid]][1], TestData_Points[DMV_Testing[playerid]-1][DMV_Index[playerid]][2], TestData_Points[DMV_Testing[playerid]-1][DMV_Index[playerid]+1][0], TestData_Points[DMV_Testing[playerid]-1][DMV_Index[playerid]+1][1], TestData_Points[DMV_Testing[playerid]-1][DMV_Index[playerid]+1][2], 5.0);
		}
		if(DMV_Index[playerid] == DMV_TEST_LAST_CP - 1)
		{
			switch(DMV_Testing[playerid])
			{
				case 1,2,3,4: cp_type = 1;
				case 5,6: cp_type = 4;
			}
			SetPlayerRaceCheckpointEx(playerid, cp_type, TestData_Points[DMV_Testing[playerid]-1][DMV_Index[playerid]][0], TestData_Points[DMV_Testing[playerid]-1][DMV_Index[playerid]][1], TestData_Points[DMV_Testing[playerid]-1][DMV_Index[playerid]][2], 0.0, 0.0, 0.0, 5.0);
		}
		return true;
	}
	if(IsPlayerInRangeOfPoint(playerid, 5.0, 2738.24, -2557.23, 13.69))
    {
        EndCarStealing(playerid);
    }

	return 1;
}

public OnPlayerLeaveRaceCheckpoint(playerid)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if(IsPlayerConnected(playerid) && IsPlayerWorkInBus(playerid))
	{
		switch(busRoute[playerid])
		{
			case 1: busCounter[playerid] = arr_busRoute1[currentBRoute[playerid]][b_time];
			case 2: busCounter[playerid] = arr_busRoute2[currentBRoute[playerid]][b_time];
			case 3: busCounter[playerid] = arr_busRoute3[currentBRoute[playerid]][b_time];
		}
	}

	return 1;
}
// GOTO MAP ATAUK GOTO KLICK MAP
public OnPlayerClickMap(playerid, Float:fX, Float:fY, Float:fZ)
{
	if(IsPlayerNPC(playerid))
        return 1;

	if(!IsPlayerConnected(playerid))
		return 1;

	if (CheckAdmin(playerid, 3))
	    return SendErrorMessage(playerid, "Kamu butuh rank 3 untuk melakukan perintah ini.");

	if(PlayerData[playerid][pAdminDuty])
	{
		if(IsPlayerInAnyVehicle(playerid))
		{
			SetVehiclePos(GetPlayerVehicleID(playerid), fX, fY, fZ);
		}
		else
		{
			SetPlayerPos(playerid, fX, fY, fZ);
			SendAdminMessage(X11_LIGHTBLUE,"[AdmCmd] "RED"%s"LIGHTBLUE" telah teleportasi ke kordinat : "RED"%f, %f, %f", ReturnName(playerid), fX, fY, fZ);
		}
	}
	if(IsPlayerInAnyVehicle(playerid))
	{
		foreach(new i:Player)
		{
			if(IsPlayerInAnyVehicle(i) && GetPlayerVehicleID(i) == GetPlayerVehicleID(playerid) && i != playerid)
			{
				if(!IsPlayerWorkInBus(i) && !PlayerData[i][pCarStealing] && PlayerData[playerid][pMissions] == 0)
				{
					SetPlayerWaypoint(i, "Share Location", fX, fY, fZ);
					SendCustomMessage(i, "Location", "%s have you the location on the map.", ReturnName(playerid));
					va_SendClientMessage(i, -1, "");
				}
			}
		}
	}
	return true;
}

stock DisplayVehicleAttachment(playerid)
{
    new
        id = -1,
        str[255];

    if(!IsPlayerInAnyVehicle(playerid))
        return SendErrorMessage(playerid, "Kamu harus menjadi pengemudi.");

	if(PlayerData[playerid][pVIP] < 1) return SendErrorMessage(playerid, "Kamu bukan VIP player.");

    if(IsPlayerInModshop(playerid) != -1)
    {
        if((id = Vehicle_GetID(GetPlayerVehicleID(playerid))) != -1)
        {
            if(GetEngineStatus(GetPlayerVehicleID(playerid)))
                return SendErrorMessage(playerid, "Matikan mesin kendaraan terlebih dahulu.");

            for (new i = 0; i < MAX_VEHICLE_OBJECT; i++)
            {
                if(VehicleObjects[id][i][object_exists]) format(str, sizeof(str), "%s%d: %s\n", str, i+1, (VehicleObjects[id][i][object_type] == OBJECT_TYPE_BODY) ? (Bodypart_Name(VehicleObjects[id][i][object_model])) : ("Sticker"));
                else format(str, sizeof(str), "%s%d: Empty\n", str, i+1);
            }

			SetVehiclePos(GetPlayerVehicleID(playerid), -1509.36,752.34,7.21);
			SetVehicleZAngle(GetPlayerVehicleID(playerid), 0.0);

            PlayerData[playerid][pVObject] = id;
            Dialog_Show(playerid, VACCS, DIALOG_STYLE_LIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Vehicle Accesories", str, "Select", "Close");
            return 1;
        }

        return 1;
    }
    SendErrorMessage(playerid, "Kamu tidak berada di modshop.");
    return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
	printf("OnVehicleDeath vehicleid: %d | killerid: %d", vehicleid, killerid);

	new id = -1;
    if ((id = Vehicle_GetID(vehicleid)) != -1) 
	{

		#if defined VEHICLE_PLATE_LABEL
		if(VehicleData[vehicleid][cPlateLabel] != Text3D:INVALID_STREAMER_ID)
			DestroyDynamic3DTextLabel(VehicleData[vehicleid][cPlateLabel]),
			VehicleData[vehicleid][cPlateLabel] = Text3D:INVALID_STREAMER_ID;
		#endif

		if(IsValidDynamicObject(VehicleData[id][cNeonObject][0]))
            DestroyDynamicObject(VehicleData[id][cNeonObject][0]);

        if(IsValidDynamicObject(VehicleData[id][cNeonObject][1]))
            DestroyDynamicObject(VehicleData[id][cNeonObject][1]);

        VehicleData[id][cNeonObject][0] = VehicleData[id][cNeonObject][1] = INVALID_STREAMER_ID;

        for(new slot = 0; slot != MAX_VEHICLE_OBJECT; slot++) if(VehicleObjects[id][slot][object_exists])
        {
            if(IsValidDynamicObject(VehicleObjects[id][slot][object_streamer]))
                DestroyDynamicObject(VehicleObjects[id][slot][object_streamer]);

            VehicleObjects[id][slot][object_streamer] = INVALID_STREAMER_ID;
        }

        Vehicle_GetStatus(id);

        VehicleData[id][cDead] = 1;
        VehicleData[id][cKillerID] = killerid;
		SendAdminDutyMessage(X11_RED, "[VDL-LOG]: "YELLOW"%s(%s) has destroyed %s owned %s", ReturnName(killerid), ReturnAdminName(killerid), GetVehicleNameEx(VehicleData[id][cModel]), GetSQLName(VehicleData[id][cOwner]));
    }

	foreach(new i : Player)
	{
		if(vehicleid == PlayerData[i][pCarStealing])
		{
			PlayerData[i][pCarStealingTime] = 0;
			PlayerData[i][pCarStealingDelay] = 120;
   			PlayerData[i][pCarStealing] = false;
			DisablePlayerCheckpoint(i);
			SendServerMessage(i, "Car Stealing Mission Fail because the vehicle has been destroyed");
			DestroyVehicle(PlayerData[i][pCarStealingVehicle]);
			PlayerData[i][pCarStealingVehicle] = INVALID_VEHICLE_ID;
			break;
		}
	}

	return 1;
}

Vehicle_GetOwner(id) {
    foreach(new i : Player) if(VehicleData[id][cOwner] == PlayerData[i][pID]) {
        return i;
    }
    return 0;
}

public OnVehicleSpawn(vehicleid)
{
	defer Vehicle_UpdatePosition(vehicleid);

	#if defined ENABLE_VEHICLE_LABEL
	if(IsEngineVehicle(vehicleid) && !GetEngineStatus(vehicleid))
	{
		if(VehicleLabel[vehicleid] != Text3D:INVALID_STREAMER_ID)
			DestroyDynamic3DTextLabel(VehicleLabel[vehicleid]),
			VehicleLabel[vehicleid] = Text3D:INVALID_STREAMER_ID;

		VehicleLabel[vehicleid] = CreateDynamic3DTextLabel(""WHITE"Press the [ "GREEN"n "WHITE"] button to open the vehicle radial menu", X11_WHITE, 0.0, 0.0, 0.0, 12.0, INVALID_PLAYER_ID, vehicleid, 0, -1, -1, -1, 25.0);
	}
	#endif

	new id = -1;
	for(new vid = 1; vid < sizeof(JobVehicle); vid++) if(JobVehicle[vid][Vehicle] != INVALID_VEHICLE_ID)
	{
		if(vehicleid == JobVehicle[vid][Vehicle])
		{
			foreach(new i : Player)
			{
				if(PlayerData[i][pJobVehicle] == JobVehicle[vid][Vehicle])
				{
					if(PlayerData[i][pJobVehicle] != 0)
					{
						DestroyJobVehicle(i);
						PlayerData[i][pJobVehicle] = 0;
						break;
					}
				}
			}
		}
	}
    if ((id = Vehicle_GetID(vehicleid)) != -1)
	{
        if (VehicleData[id][cDead])
		{
		    if(VehicleData[id][cRental] != -1)
			{
				foreach(new pid : Player) if (VehicleData[id][cOwner] == PlayerData[pid][pID])
        		{
					PlayerData[pid][pBank] -= 1000;
            		va_SendClientMessage(pid, X11_LIMEGREEN, "[Rental]: "WHITE"Kendaraan Rental milikmu "YELLOW"(%s)"WHITE" telah hancur, kamu dikenai denda sebesar "GREEN"$1000", GetVehicleNameEx(GetVehicleModel(vehicleid)));
				}
				Vehicle_Delete(id);
			}
			else if(VehicleData[id][cOwner] > 0) 
			{
				new
				query[255];
				VehicleData[id][cInsuTime] = gettime() + (1 * 86400);
				VehicleData[id][cInsuranced] = true;

				foreach(new pid : Player) if (VehicleData[id][cOwner] == PlayerData[pid][pID])
				{
					SendServerMessage(pid, "Your vehicle %s has been destroyed you can claim your vehicle from insurance.", GetVehicleNameEx(vehicleid));
				}

				#if defined VEHICLE_PLATE_LABEL
				if(VehicleData[id][cPlateLabel] != Text3D:INVALID_STREAMER_ID)
				DestroyDynamic3DTextLabel(VehicleData[id][cPlateLabel]),
				VehicleData[id][cPlateLabel] = Text3D:INVALID_STREAMER_ID;
				#endif

				format(query, sizeof(query), "INSERT INTO `cardestroy` SET `destroyBy`='%s', `destroyModel`='%d', `destroyOwner`='%s', `destroyTime`=UNIX_TIMESTAMP()", ReturnName(VehicleData[id][cKillerID]), VehicleData[id][cModel], ReturnName(Vehicle_GetOwner(id)));
				mysql_tquery(g_SQL, query);

			}
			if(VehicleData[id][cVehicle] != INVALID_VEHICLE_ID)
			DestroyVehicle(VehicleData[id][cVehicle]), VehicleData[id][cVehicle] = INVALID_VEHICLE_ID;
 			VehicleData[id][cDead] = 0;
			VehicleData[id][cKillerID] = INVALID_PLAYER_ID;
		}
	}
	ResetVehicle(vehicleid);
	return 1;
} 

stock ShowSegel(playerid)
{
    for (new i = 0; i < 6; i++)
    {
        if (UI_Segel[playerid][i] != INVALID_TEXT_DRAW)
        {
            PlayerTextDrawShow(playerid, UI_Segel[playerid][i]);
        }
    }
}
stock HideSegel(playerid)
{
    for (new i = 0; i < 6; i++)
    {
        if (UI_Segel[playerid][i] != INVALID_TEXT_DRAW)
        {
            PlayerTextDrawHide(playerid, UI_Segel[playerid][i]);
        }
    }
}
UpdateHUD(playerid);
public OnPlayerUpdate(playerid)
{
	//pumpkin
	if(IsPlayerInRangeOfPoint(playerid, 2.5, 1128.91, -1430.73, 15.79))
    {
        if(!PlayerData[playerid][pPumpkinDialog])
        {
            PlayerData[playerid][pPumpkinDialog] = true;
            Dialog_Show(playerid, DIALOG_PUMPKIN_REDEEM, DIALOG_STYLE_MSGBOX, "🎃 Pumpkin Redemption", "Halo, kamu menang banyak ya hari ini!\n\nTekan OK untuk menukar semua pumpkin yang kamu punya.", "Tukar", "Batal");
        }
    }
    else
    {
        PlayerData[playerid][pPumpkinDialog] = false;
    }
	
	if (gFlyMode[playerid])
	{

		new keys, ud, lr;
		GetPlayerKeys(playerid, keys, ud, lr);

		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid, x, y, z);

		if (ud == KEY_UP) z += gFlySpeed;
		if (ud == KEY_DOWN) z -= gFlySpeed;
		if (lr == KEY_LEFT) x -= gFlySpeed;
		if (lr == KEY_RIGHT) x += gFlySpeed;

		SetPlayerPos(playerid, x, y, z);
	}
	
	if(IsPlayerInEvent(playerid) && !EventData[eventStarted]) 
	{
    ResetPlayerWeapons(playerid); // kosongkan senjata
	}

	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_BOMBOMCAR_SELECT)
    {
        if(!response) return 1; // Pemain klik "Batal"

		// Hancurkan kendaraan lama jika masih ada
        if (playerBombomCar[playerid] != INVALID_VEHICLE_ID)
        {
            DestroyVehicle(playerBombomCar[playerid]);
            playerBombomCar[playerid] = INVALID_VEHICLE_ID;
        }
		
		// Tentukan modelid berdasarkan pilihan
		new modelid = 0;
		if (listitem == 0) modelid = 539;
		else if (listitem == 1) modelid = 571;
		else return SendClientMessage(playerid, -1, "Pilihan tidak valid.");
		
		// Validasi modelid
	    if (modelid == 0) return SendClientMessage(playerid, -1, "Model kendaraan tidak ditemukan.");
		       // Spawn kendaraan hanya lewat fungsi modular
        playerBombomCar[playerid] = SpawnBombomCar(playerid, modelid);
		if (listitem == 0)
        {
           modelid = 539; // Kendaraan 1
        }
        else if (listitem == 1)
        {
           modelid = 571; // Kendaraan 2
        }
        else
        {
            SendClientMessage(playerid, -1, "Pilihan tidak valid.");
            return 1;
        }
 
		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid, x, y, z);
		//playerBombomCar[playerid] = CreateVehicle(modelid, x, y, z + 1.0, 0.0, -1, -1, 0);
		CoreVehicles[playerBombomCar[playerid]][vehFuel] = 500;
		SetVehicleVirtualWorld(playerBombomCar[playerid], GetPlayerVirtualWorld(playerid));

		if (IsPlayerInAnyVehicle(playerid)) RemovePlayerFromVehicle(playerid);
		PutPlayerInVehicle(playerid, playerBombomCar[playerid], 0);

		SendClientMessage(playerid, -1, "Bom-bom car kamu sudah terspawn!");
		bombomCarTimerValue[playerid] = TIMER_BOMBOMCAR * 60;
		bombomCarTimer[playerid] = SetTimerEx("DestroyPlayerBombomCar", 1000, true, "i", playerid);

		//playerBombomCar[playerid] = SpawnBombomCar(playerid, modelid);
        
	}
	if(dialogid == DIALOG_VALET)
    {
        if(!response) return 1;

        // Ambil ID kendaraan dari list
        new vehicleid = strval(inputtext);
        if(!IsValidVehicle(vehicleid))
            return SendErrorMessage(playerid, "Kendaraan tidak valid.");

        // Cek apakah sedang dikendarai orang lain
        if(GetVehicleDriver(vehicleid) != INVALID_PLAYER_ID)
            return SendErrorMessage(playerid, "Kendaraan sedang dikendarai orang lain.");

        // Ambil posisi player
        new Float:x, Float:y, Float:z, Float:angle;
        GetPlayerPos(playerid, x, y, z);
        GetPlayerFacingAngle(playerid, angle);

        // Spawn kendaraan di depan player
        x += floatsin(-angle, degrees) * 5.0;
        y += floatcos(-angle, degrees) * 5.0;

        SetVehiclePos(vehicleid, x, y, z);
        SetVehicleZAngle(vehicleid, angle);

        SendClientMessage(playerid, -1, "Valet telah memanggil kendaraanmu.");
    }
    return 1;
}
stock SpawnBombomCar(playerid, modelid)
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    new vehicleid = CreateVehicle(modelid, x, y, z + 1.0, 0.0, -1, -1, 0);
    CoreVehicles[vehicleid][vehFuel] = 500;
    SetVehicleVirtualWorld(vehicleid, GetPlayerVirtualWorld(playerid));
    if (IsPlayerInAnyVehicle(playerid)) RemovePlayerFromVehicle(playerid);
    PutPlayerInVehicle(playerid, vehicleid, 0);
    return vehicleid;
}

//ini untuk /ann 
forward CloseAnnounceTD();
public CloseAnnounceTD()
{
    for (new i; i < 7; i++) TextDrawHideForAll(AnnouncementTD[i]);
    return 1;
}
ShowAnnouncement(playerid, byadmin[], desk[])
{
    TextDrawSetString(AnnouncementTD[1], sprintf("Server Announcement by Admin: %s", byadmin));
    TextDrawSetString(AnnouncementTD[2], desk);
    for (new i; i < 7; i++) TextDrawShowForPlayer(playerid, AnnouncementTD[i]);
}

//// crafting tapi gk berfungsi 

stock ShowCraftingInterface(playerid)
{
    for (new i = 0; i < sizeof(Text_Gun); i++)
    {
        TextDrawShowForPlayer(playerid, Text_Gun[i]);
    }
    SelectTextDraw(playerid, 0xFFFFFFFF); // Aktifkan klik
}

stock HideCraftingInterface(playerid)
{
    for (new i = 0; i < sizeof(Text_Gun); i++)
    {
        TextDrawHideForPlayer(playerid, Text_Gun[i]);
    }
    CancelSelectTextDraw(playerid);
}

stock StartTableCrafting(playerid, weapindex)
{
    if (weapindex < sizeof(CraftSenjata))
    {
        if (Inventory_Count(playerid, "Aluminium") < CraftSenjata[weapindex][senjataMaterial]) return SendErrorMessage(playerid, "Kamu tidak punya Aluminium.");
        if (Inventory_Count(playerid, "Component") < CraftSenjata[weapindex][senjataItem1]) return SendErrorMessage(playerid, "Kamu tidak punya Component.");
        if (Inventory_Count(playerid, "Planks Cut") < CraftSenjata[weapindex][senjataItem2]) return SendErrorMessage(playerid, "Kamu tidak punya Planks Cut.");

        if (IsInventoryFull(playerid, CraftSenjata[weapindex][senjataName], 1)) return SendErrorMessage(playerid, "Inventory penuh.");

        if (PlayerData[playerid][pActivityTime] == -1)
        {
            PlayerData[playerid][pActivityTime] = 0;
            ShowActivityBarTD(playerid, "CRAFT SENJATA");
            ApplyAnimation(playerid, "BD_FIRE", "wash_up", 4.1, 1, 0, 0, 0, 0, true);
            PlayerData[playerid][pActivity] = SetTimerEx("CraftingSenjata", 3000, true, "ddd", playerid, weapindex, 5);
        }
    }
    else if (weapindex == 4) // ARMOR = CraftVest[0]
    {
        if (Inventory_Count(playerid, "Aluminium") < CraftVest[0][vestMaterial]) return SendErrorMessage(playerid, "Kamu tidak punya Aluminium.");
        if (Inventory_Count(playerid, "Plastic") < CraftVest[0][vestItem1]) return SendErrorMessage(playerid, "Kamu tidak punya Plastic.");
        if (Inventory_Count(playerid, "Fabric") < CraftVest[0][vestItem2]) return SendErrorMessage(playerid, "Kamu tidak punya Fabric.");

        if (IsInventoryFull(playerid, CraftVest[0][vestName], 1)) return SendErrorMessage(playerid, "Inventory penuh.");

        if (PlayerData[playerid][pActivityTime] == -1)
        {
            PlayerData[playerid][pActivityTime] = 0;
            ShowActivityBarTD(playerid, "CRAFT VEST");
            ApplyAnimation(playerid, "BD_FIRE", "wash_up", 4.1, 1, 0, 0, 0, 0, true);
            PlayerData[playerid][pActivity] = SetTimerEx("CraftingVest", 3000, true, "ddd", playerid, 0, 5);
        }
    }
	
    if (Inventory_Count(playerid, "Dirty Money") < CraftingTableWeap[weapindex][WEAPMaterial])
        return SendErrorMessage(playerid, "Uang merah kamu tidak cukup.");

    if (IsInventoryFull(playerid, CraftingTableWeap[weapindex][WEAPName], 1))
        return SendErrorMessage(playerid, "Inventory kamu penuh.");

    if (PlayerData[playerid][pActivityTime] == -1)
    {
        PlayerData[playerid][pActivityTime] = 0;
        ShowActivityBarTD(playerid, "Crafting Items");
        ApplyAnimation(playerid, "BD_FIRE", "wash_up", 4.1, 1, 0, 0, 0, 0, true);
        PlayerData[playerid][pActivity] = SetTimerEx("CraftingTableWeapon", 1000, true, "ddd", playerid, weapindex, 5);
    }
	return 1;
}

//TD KICK
stock KickTdLuxxy(playerid, status[])
{
    for (new i = 0; i < 6; i++) TextDrawShowForPlayer(playerid, tdkickbyluxxy1[i]);
    for (new i = 0; i < 5; i++) PlayerTextDrawShow(playerid, tdkickbyluxxy2[playerid][i]);

    new LuxxyJuniorr[128];
    format(LuxxyJuniorr, sizeof(LuxxyJuniorr), "Alasan : %s", status);
    PlayerTextDrawSetString(playerid, tdkickbyluxxy2[playerid][4], LuxxyJuniorr);

    SetTimerEx("KickPublic", 200, false, "d", playerid);
    return 1;
}
forward KickPublic(playerid);
public KickPublic(playerid)
{
    KickEx(playerid);
    return 1;
}

//tdwarn
stock PeringatanTdLuxxy(playerid, status[])
{
    for (new i = 0; i < 6; i++) TextDrawShowForPlayer(playerid, tdwarn1[i]);
    for (new i = 0; i < 5; i++) PlayerTextDrawShow(playerid, tdwarn2[playerid][i]);

    new warningText[128];
    format(warningText, sizeof(warningText), "Peringatan : %s", status);
    PlayerTextDrawSetString(playerid, tdwarn2[playerid][4], warningText);

    SetTimerEx("HidePeringatanTd", 3000, false, "d", playerid);
    return 1;
}

forward HidePeringatanTd(playerid);
public HidePeringatanTd(playerid)
{
    for (new i = 0; i < 6; i++) TextDrawHideForPlayer(playerid, tdwarn1[i]);
    for (new i = 0; i < 5; i++) PlayerTextDrawHide(playerid, tdwarn2[playerid][i]);
    return 1;
}

///megaphone////
//new SV_LSTREAM:lstream[MAX_PLAYERS];
EnableMegaphone(playerid)
{
    PlayerData[playerid][pMegaphone] = true;
    ShowMegaphoneTextdraw(playerid);
    //lstream[playerid] = SvCreateDLStreamAtPlayer(100.0, SV_INFINITY, playerid, 0xff0000ff, "Megaphone");
	SendServerMessage(playerid, "Megaphone aktif. Suara kamu akan terdengar lebih jauh.");
    SetTimerEx("DisableMegaphone", 60000, false, "d", playerid); // Auto-off 60 detik
}

forward DisableMegaphone(playerid);
public DisableMegaphone(playerid)
{
    PlayerData[playerid][pMegaphone] = false;
    HideMegaphoneTextdraw(playerid);
    //lstream[playerid] = SvCreateDLStreamAtPlayer(15.0, SV_INFINITY, playerid, 0xff0000ff, "Megaphone");
	SendServerMessage(playerid, "Megaphone dimatikan.");
    return 1;
}
stock ShowMegaphoneTextdraw(playerid)
{
    PlayerTextDrawShow(playerid, tdmegaphone[playerid]);
}

stock HideMegaphoneTextdraw(playerid)
{
    PlayerTextDrawHide(playerid, tdmegaphone[playerid]);
}

stock IsPlayerInFactionGarageVehicle(playerid)
{
    new vehicleid = GetPlayerVehicleID(playerid);
    if(vehicleid == 0) return false;

    foreach(new i : PlayerVehicle)
    {
        if(
            VehicleData[i][cExists] &&
            VehicleData[i][cVehicle] == vehicleid &&
            VehicleData[i][cFaction] == PlayerData[playerid][FACTION_POLICE]
        )
        {
            return true;
        }
    }
    return false;
}


