#include <a_samp>
#include <core>
#include <float>
#include <easyDialog>
#include <sampvoice>
#include <izcmd>

#define SERVER_NAME "Sevolt Roleplay"
#define SERVER_LOGO  "{fcbc04}/{ffffff}/"
#define WHITE                        "{FFFFFF}"

main() {}

#define MAX_FREQUENCY (1000)

new SV_GSTREAM:RadioFrequency[MAX_FREQUENCY];
new SV_GSTREAM:PhoneFrequency[MAX_FREQUENCY];

new PhoneFreq[MAX_PLAYERS];

new SV_LSTREAM:lstream[MAX_PLAYERS] = { SV_NULL, ... };

enum playerData {
    pToggleRadio,
	pFrequency,
	pRadioTalk,
	pCallLine,
	pIncomingCall,
	pVoicemode
}
new PlayerData[MAX_PLAYERS][playerData];


new CurrentAnim[MAX_PLAYERS];

forward SV_OnPlayerRadioTalk(playerid, playerData:mode);
public SV_OnPlayerRadioTalk(playerid, playerData:mode)
{
    PlayerData[playerid][pRadioTalk] = mode;
	return 1;
}


forward SV_OnPlayerRadio(playerid, playerData:mode, freq);
public SV_OnPlayerRadio(playerid, playerData:mode, freq)
{
	PlayerData[playerid][pFrequency] = freq;
    PlayerData[playerid][pToggleRadio] = mode;
    if(PlayerData[playerid][pToggleRadio])
    {
        
		SvAttachListenerToStream(RadioFrequency[PlayerData[playerid][pFrequency]], playerid);
    }
    else
    {
        SvDetachListenerFromStream(RadioFrequency[PlayerData[playerid][pFrequency]], playerid);
    }
	return 1;
}

SetVoiceTextdraw(playerid, mode)
{
	return CallRemoteFunction("SetVoiceMode", "dd", playerid, mode);
}

SendClientMessageEx(playerid, color, const text[], {Float, _}:...)
{
    static
        args,
            str[144];

    if((args = numargs()) == 3)
    {
            SendClientMessage(playerid, color, text);
    }
    else
    {
        while (--args >= 3)
        {
            #emit LCTRL 5
            #emit LOAD.alt args
            #emit SHL.C.alt 2
            #emit ADD.C 12
            #emit ADD
            #emit LOAD.I
            #emit PUSH.pri
        }
        #emit PUSH.S text
        #emit PUSH.C 144
        #emit PUSH.C str
        #emit PUSH.S 8
        #emit SYSREQ.C format
        #emit LCTRL 5
        #emit SCTRL 4

        SendClientMessage(playerid, color, str);

        #emit RETN
    }
    return 1;
}


forward SV_CancelCall(playerid, targetid, frequency);
public SV_CancelCall(playerid, targetid, frequency)
{
	PhoneFreq[playerid] = frequency;
	PhoneFreq[targetid] = frequency;

	PlayerData[playerid][pCallLine] = INVALID_PLAYER_ID;
	PlayerData[targetid][pCallLine] = INVALID_PLAYER_ID;

	PlayerData[playerid][pIncomingCall] = 0;
	PlayerData[targetid][pIncomingCall] = 0;

	SvDetachListenerFromStream(PhoneFrequency[frequency], playerid);
	SvDetachListenerFromStream(PhoneFrequency[frequency], targetid);

	SvDetachSpeakerFromStream(PhoneFrequency[frequency], playerid);
	SvDetachSpeakerFromStream(PhoneFrequency[frequency], targetid);

	//SendClientMessageEx(playerid, -1, "[DEBUG] Telah menutup handphone dari id %d (frequency: %d)", targetid, frequency);
	//SendClientMessageEx(targetid, -1, "[DEBUG] Telah menutup handphone dari id %d (frequency: %d)", playerid, frequency);
	return 1;
}

forward SV_OnPlayerPhone(playerid, targetid, frequency);
public SV_OnPlayerPhone(playerid, targetid, frequency)
{
	PlayerData[playerid][pCallLine] = targetid;
	PlayerData[targetid][pCallLine] = targetid;
	PhoneFreq[playerid] = frequency;
	PhoneFreq[targetid] = frequency;

	SvAttachListenerToStream(PhoneFrequency[PhoneFreq[playerid]], playerid);
	SvAttachListenerToStream(PhoneFrequency[PhoneFreq[playerid]], targetid);

	//SendClientMessageEx(playerid, -1, "[DEBUG] Telah tersambung ke frekuensi phone id %d (frequency: %d)", targetid, frequency);
	//SendClientMessageEx(targetid, -1, "[DEBUG] Telah tersambung ke frekuensi phone id %d (frequency: %d)", playerid, frequency);
	return 1;
}

public SV_VOID:OnPlayerActivationKeyPress(SV_UINT:playerid, SV_UINT:keyid) 
{
	if(keyid == 0x42)
	{
		if(PlayerData[playerid][pCallLine] != INVALID_PLAYER_ID && !PlayerData[playerid][pIncomingCall])
		{
			SetPlayerChatBubble(playerid, "{33AA33}Calling..", 0xFFFF00AA, 10.0, 60000);
			SvAttachSpeakerToStream(PhoneFrequency[PhoneFreq[playerid]], playerid);
		}
		if (keyid == 0x42 && PlayerData[playerid][pToggleRadio] == 1 && PlayerData[playerid][pRadioTalk] && RadioFrequency[PlayerData[playerid][pFrequency]] >= 1)
		{
			if(GetPlayerAnimationIndex(playerid) == 1275 || GetPlayerAnimationIndex(playerid) == 1189)
			{
				CurrentAnim[playerid] = 1;
				ApplyAnimation(playerid, "ped", "phone_talk", 4.1, 1, 1, 1, 1, 1, 1);
			}
			else
			{
				CurrentAnim[playerid] = 0;
			}
			
			if(!IsPlayerAttachedObjectSlotUsed(playerid, 9)) SetPlayerAttachedObject(playerid, 9, 18868, 6, 0.0789, 0.0050, -0.0049, 84.9999, -179.2999, -1.6999, 1.0000, 1.0000, 1.0000);

			for(new i = GetPlayerPoolSize(); i != -1; --i)
			{
				if(IsPlayerConnected(i))
				{
					if(PlayerData[i][pFrequency] == PlayerData[playerid][pFrequency] && PlayerData[i][pToggleRadio] == 1)
					{
						new Float:x, Float:y, Float:z;
						GetPlayerPos(i, Float:x, Float:y, Float:z);
						PlayerPlaySound(i, 21000, Float:x, Float:y, Float:z);
						SetTimerEx("RadioSound", 300, false, "d", i);
					}
				}
			}
			SetPlayerChatBubble(playerid, "{33AA33}Radio..", 0x87CEEBAA, 10.0, 60000);
			SvAttachSpeakerToStream(RadioFrequency[PlayerData[playerid][pFrequency]], playerid);
			// printf("[DEBUG] Player %d has started talking on radio frequency %d", playerid, PlayerData[playerid][pFrequency]);
		}

		if (keyid == 0x42 && !PlayerData[playerid][pRadioTalk] && lstream[playerid])
		{ 
			SvAttachSpeakerToStream(lstream[playerid], playerid);
			SetPlayerChatBubble(playerid, "{33AA33}Talking..", 0xFFFF00AA, 10.0, 60000);
		}
	}
}

forward RadioSound(playerid);
public RadioSound(playerid)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid, Float:x, Float:y, Float:z);
	PlayerPlaySound(playerid, 21000, Float:x, Float:y, Float:z);
	return 1;
}

public SV_VOID:OnPlayerActivationKeyRelease(SV_UINT:playerid, SV_UINT:keyid) 
{
	if (keyid == 0x42 && PlayerData[playerid][pCallLine] != INVALID_PLAYER_ID && !PlayerData[playerid][pIncomingCall])
	{
		SetPlayerChatBubble(playerid, "", -1, 10.0, 5000);
		SvDetachSpeakerFromStream(PhoneFrequency[PhoneFreq[playerid]], playerid);	
	}
	if (keyid == 0x42 && PlayerData[playerid][pToggleRadio] == 1 && PlayerData[playerid][pRadioTalk] && RadioFrequency[PlayerData[playerid][pFrequency]] >= 1)
	{
		SetPlayerChatBubble(playerid, "", -1, 10.0, 5000);
		SvDetachSpeakerFromStream(RadioFrequency[PlayerData[playerid][pFrequency]], playerid);

		if(!IsPlayerInAnyVehicle(playerid))
		{
			if(CurrentAnim[playerid] == 1)
			{
        		ApplyAnimation(playerid, "CARRY", "crry_prtial", 4.0, 0, 0, 0, 0, 0, 1);
			}
		}

		if(IsPlayerAttachedObjectSlotUsed(playerid, 9)) RemovePlayerAttachedObject(playerid, 9);
	}
	if (keyid == 0x42 && lstream[playerid]) SvDetachSpeakerFromStream(lstream[playerid], playerid), SetPlayerChatBubble(playerid, "", -1, 10.0, 5000);
}

public OnPlayerConnect(playerid) {

	CheckVoicePlugins(playerid);

	PhoneFreq[playerid] = 0;
    PlayerData[playerid][pToggleRadio] = 0;
	PlayerData[playerid][pFrequency] = 0;
	PlayerData[playerid][pRadioTalk] = 0;
	PlayerData[playerid][pCallLine] = INVALID_PLAYER_ID;
	PlayerData[playerid][pIncomingCall] = 0;
	PlayerData[playerid][pVoicemode] = 0;
	return 1;
}

forward CreatePlayerVoiceTextdraw(playerid);
public CreatePlayerVoiceTextdraw(playerid)
{
	SetVoiceTextdraw(playerid, 1);
}

stock KickEx(playerid)
{
	SetTimerEx("KickPlayer", 400, false, "d", playerid);
	return 1;
}

forward KickPlayer(playerid);
public KickPlayer(playerid)
{
	Kick(playerid);
}
stock CheckVoicePlugins(playerid)
{
	if (!SvGetVersion(playerid))
	{
		Dialog_Show(playerid, DIALOG_VOICE_ERROR, DIALOG_STYLE_MSGBOX, ""WHITE""SERVER_NAME" "SERVER_LOGO" Penjaga", "{999999}Untuk bermain di server Sevolt diwajibkan untuk menginstal plugins sampvoice\n\nOfficial Discord @: {FFFF00}https://discord.gg/SevoltRoleplay", "Close", "");

		KickEx(playerid);
	}
	else if (!SvHasMicro(playerid))
	{
		Dialog_Show(playerid, DIALOG_VOICE_ERROR, DIALOG_STYLE_MSGBOX, ""WHITE""SERVER_NAME" "SERVER_LOGO" Penjaga", "{999999}Untuk bermain di server Sevolt diwajibkan untuk menggunakan microphone\n\nOfficial Discord @: {FFFF00}https://discord.gg/SevoltRoleplay", "Close", "");

		KickEx(playerid);
	}
	else if ((lstream[playerid] = SvCreateDLStreamAtPlayer(15.0, SV_INFINITY, playerid, 0xff0000ff, "L")))
	{
		PhoneFreq[playerid] = 0;
		PlayerData[playerid][pToggleRadio] = 0;
		PlayerData[playerid][pFrequency] = 0;
		PlayerData[playerid][pRadioTalk] = 0;
		PlayerData[playerid][pCallLine] = INVALID_PLAYER_ID;
		PlayerData[playerid][pIncomingCall] = 0;
		SvAddKey(playerid, 0x42);

	}
	return 1;
}

CMD:sv(playerid, params[])
{
    Dialog_Show(playerid, DIALOG_VOICE_MODE, DIALOG_STYLE_TABLIST, ""WHITE""SERVER_NAME" "SERVER_LOGO" Voice Mode", "Berbisik (5.0 Meters)\nNormal (15.00 Meters)\nTeriak (35.00 Meters)", "Pilih", "Keluar");
    return 1;
}

Dialog:DIALOG_VOICE_MODE(playerid, response, listitem, inputtext[])
{
    if(!response) return 1;
    switch(listitem)
    {
        case 0:
        {
            lstream[playerid] = SvCreateDLStreamAtPlayer(10.0, SV_INFINITY, playerid, 0xff0000ff, "L");
			SendClientMessageEx(playerid, -1, "{3BBD44}[Info]"WHITE" Kamu telah mengubah mode voice ke berbisik.");
			PlayerData[playerid][pVoicemode] = 0;
        }
        case 1:
        {
            lstream[playerid] = SvCreateDLStreamAtPlayer(15.0, SV_INFINITY, playerid, 0xff0000ff, "L");
            SendClientMessageEx(playerid, -1, "{3BBD44}[Info]"WHITE" Kamu telah mengubah mode voice ke normal.");
			PlayerData[playerid][pVoicemode] = 1;
        }
        case 2:
        {
            lstream[playerid] = SvCreateDLStreamAtPlayer(20.0, SV_INFINITY, playerid, 0xff0000ff, "L");
            SendClientMessageEx(playerid, -1, "{3BBD44}[Info]"WHITE" Kamu telah mengubah mode voice ke berteriak.");
			PlayerData[playerid][pVoicemode] = 2;
        }
    }
	SetVoiceTextdraw(playerid, listitem);
    return 1;
}

public OnPlayerDisconnect(playerid, reason) 
{
	PhoneFreq[playerid] = 0;
    PlayerData[playerid][pToggleRadio] = 0;
	PlayerData[playerid][pFrequency] = 0;
	PlayerData[playerid][pRadioTalk] = 0;
	PlayerData[playerid][pCallLine] = INVALID_PLAYER_ID;
	PlayerData[playerid][pIncomingCall] = 0;
	return 1;
}

public OnFilterScriptInit() {
	//SvDebug(SV_TRUE);
	
	for(new i; i < MAX_FREQUENCY; i++)
    {        
        RadioFrequency[i] = SvCreateGStream(0xffff0000, "Radio");
    }
	for(new i; i < MAX_FREQUENCY; i++)
	{
		PhoneFrequency[i] = SvCreateGStream(0xffff0000, "Phone");
	}
	return 1;
	
}

