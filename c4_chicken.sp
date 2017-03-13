/*  SM C4 chicken
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#include <sdkhooks>
#include <cstrike>

#define PLUGIN_VERSION "1.3"


new gallina = -1;



new Handle:hPush;
new Handle:hHeight;
new Handle:SpeedGallina;

new g_Collision;

new VelocityOffset_0;
new VelocityOffset_1;
new BaseVelocityOffset;

new Float:g_explosionTime;
new g_countdown;
new Handle:hTimer = INVALID_HANDLE;

new Handle:mp_c4timer;
//new Handle:finaldelay;

public Plugin:myinfo =
{
	name = "SM C4 chicken",
	author = "Franc1sco Steam: franug",
	description = "c4 be a chicken",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/franug"
};

public OnPluginStart()
{

	CreateConVar("sm_c4chicken_version", PLUGIN_VERSION, "version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	HookEvent("bomb_planted", BomPlanted_Event);


	HookEvent("player_spawn", Event_Player_Spawn);

	HookEvent("round_start", Event_Round_Start, EventHookMode_Pre);
	HookEvent("round_end", Event_Round_End);

	//HookEvent( "bomb_exploded", Event_BombExploded );

	HookEvent("bomb_planted", EventBombPlanted, EventHookMode_Pre);
	HookEvent("bomb_defused", EventBombDefused);	

	HookEvent("bomb_begindefuse", Event_BombBeginDefuse);
	HookEvent("bomb_abortdefuse", Event_BombAbortDefuse);
	g_Collision = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	HookEvent("player_death", Event_Player_Death);
	HookEvent("player_jump", PlayerJump);

	hPush = CreateConVar("sm_c4chicken_push","0.5", "push in jump for chicken");
	hHeight = CreateConVar("sm_c4chicken_height","1.0", "height in jump for chicken");
	SpeedGallina = CreateConVar("sm_c4chicken_speed", "0.9", "speed of chicken");

    	mp_c4timer = FindConVar("mp_c4timer");
    	SetConVarBounds(mp_c4timer, ConVarBound_Upper, true, 346.0);

    	//finaldelay = FindConVar("mp_round_restart_delay");


	// FIND OFFSET
	VelocityOffset_0=FindSendPropOffs("CBasePlayer","m_vecVelocity[0]");
	if (VelocityOffset_0==-1)
		SetFailState("[BunnyHop] Error: Failed to find Velocity[0] offset, aborting");
	VelocityOffset_1=FindSendPropOffs("CBasePlayer","m_vecVelocity[1]");
	if (VelocityOffset_1==-1)
		SetFailState("[BunnyHop] Error: Failed to find Velocity[1] offset, aborting");
	BaseVelocityOffset=FindSendPropOffs("CBasePlayer","m_vecBaseVelocity");
	if (BaseVelocityOffset==-1)
		SetFailState("[BunnyHop] Error: Failed to find the BaseVelocity offset, aborting");
}

public OnConfigsExecuted()
{
	AddFileToDownloadsTable("materials/models/lduke/chicken/chicken2.vmt");
	AddFileToDownloadsTable("materials/models/lduke/chicken/chicken2.vtf");
	AddFileToDownloadsTable("models/lduke/chicken/chicken2.dx80.vtx");
	AddFileToDownloadsTable("models/lduke/chicken/chicken2.dx90.vtx");
	AddFileToDownloadsTable("models/lduke/chicken/chicken2.mdl");
	AddFileToDownloadsTable("models/lduke/chicken/chicken2.phy");
	AddFileToDownloadsTable("models/lduke/chicken/chicken2.sw.vtx");
	AddFileToDownloadsTable("models/lduke/chicken/chicken2.vvd");
	PrecacheModel("models/lduke/chicken/chicken2.mdl");

	AddFileToDownloadsTable("sound/lduke/chicken/chicken.wav");
	PrecacheSound("lduke/chicken/chicken.wav");

	AddFileToDownloadsTable("sound/knifefight/chicken.wav");
	PrecacheSound("knifefight/chicken.wav");
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}


public Action:Event_Round_End(Handle:event, const String:name[], bool:dontBroadcast) 
{
	QuitarGallina();
}

/*
public Action:pasado(Handle:timer)
{
	if(clientevalido(gallina))
	{
		CS_RespawnPlayer(gallina);
		ForcePlayerSuicide(gallina);
		SetEntProp(gallina, Prop_Data, "m_iFrags", GetClientFrags(gallina)+1);
		new olddeaths = GetEntProp(gallina, Prop_Data, "m_iDeaths");
		SetEntProp(gallina, Prop_Data, "m_iDeaths", olddeaths-1);

	}
}
*/

public Action:EventBombPlanted(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	g_explosionTime = GetEngineTime() + GetConVarFloat(mp_c4timer);
	
	
	g_countdown = GetConVarInt(mp_c4timer) - 1;

	hTimer = CreateTimer((g_explosionTime - float(g_countdown)) - GetEngineTime(), TimerCountdown);
	
}

/*
public Action:Event_BombExploded( Handle:event, const String:name[], bool:dontBroadcast )
{
	QuitarGallina();
}
*/

public EventBombDefused(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(hTimer != INVALID_HANDLE)
	{
		CloseHandle(hTimer);
	}
}

public Action:TimerCountdown(Handle:timer, any:data)
{
	if(g_countdown == 1 && clientevalido(gallina))
	{
		new c4 = -1;
		c4 = FindEntityByClassname(c4, "planted_c4");
		if(c4 != -1)
			SetEntityRenderColor(c4, 255, 0, 0, 255);

		new Float:pos[3];
		GetEntPropVector(gallina, Prop_Send, "m_vecOrigin", pos);
		EmitAmbientSound("knifefight/chicken.wav", pos, gallina, SNDLEVEL_NORMAL );
	}

	if(--g_countdown)
	{
		hTimer = CreateTimer((g_explosionTime - float(g_countdown)) - GetEngineTime(), TimerCountdown);
	}
}

public Action:Event_BombAbortDefuse( Handle:event, const String:name[], bool:dontBroadcast )
{
      if(clientevalido(gallina))
      	SetEntityMoveType(gallina, MOVETYPE_WALK);
}

public Action:Event_BombBeginDefuse( Handle:event, const String:name[], bool:dontBroadcast )
{
      if(clientevalido(gallina))
      	SetEntityMoveType(gallina, MOVETYPE_NONE);
}


public Action:Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast) 
{
	QuitarGallina2();
	gallina = -1;
}

public Action:OnWeaponCanUse(client, weapon)
{
	if(gallina == client)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public PlayerJump(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (client == gallina) SaltoGallina(client);
}

SaltoGallina(client)
{
	new Float:finalvec[3];
	finalvec[0]=GetEntDataFloat(client,VelocityOffset_0)*GetConVarFloat(hPush)/2.0;
	finalvec[1]=GetEntDataFloat(client,VelocityOffset_1)*GetConVarFloat(hPush)/2.0;
	finalvec[2]=GetConVarFloat(hHeight)*50.0;
	SetEntDataVector(client,BaseVelocityOffset,finalvec,true);
	
	new Float:pos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	EmitAmbientSound("lduke/chicken/chicken.wav", pos, client, SNDLEVEL_NORMAL );
}

public Action:Event_Player_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client == gallina)
	{
		gallina = -1;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Event_Player_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client == gallina)
	{
		SetEntProp(client, Prop_Send, "m_nHitboxSet", 2);
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_nHitboxSet", 0);
	}
}

public Action:BomPlanted_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new c4 = -1;
	c4 = FindEntityByClassname(c4, "planted_c4");
	if(c4 != -1)
	{
			

			gallina = GetRandomPlayer(2);

			if(clientevalido(gallina))
			{
				SetEntityModel(c4, "models/lduke/chicken/chicken2.mdl");

				CS_RespawnPlayer(gallina);
				new weaponIndex;
				for (new i = 0; i <= 3; i++)
				{
					if ((weaponIndex = GetPlayerWeaponSlot(gallina, i)) != -1)
					{  
						RemovePlayerItem(gallina, weaponIndex);
						RemoveEdict(weaponIndex);
					}
				}


	              		new Float:Pos[3];
				GetEntPropVector(c4, Prop_Send, "m_vecOrigin", Pos);

                           	TeleportEntity(gallina, Pos, NULL_VECTOR, NULL_VECTOR);
                           	Entity_SetParent(c4, gallina);

				SetEntPropFloat(gallina, Prop_Data, "m_flLaggedMovementValue", GetConVarFloat(SpeedGallina));
				SetEntData(gallina, g_Collision, 2, 4, true);
				SetEntProp(gallina, Prop_Send, "m_lifeState", 1);

			}
	}
}

GetRandomPlayer(team)
{
	new clients[MaxClients+1], clientCount;
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == team && !IsPlayerAlive(i))
		clients[clientCount++] = i;
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
} 

public clientevalido( client ) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client)) 
        return false; 
     
    return true; 
}

QuitarGallina()
{
	if(clientevalido(gallina))
	{
		SetEntProp(gallina, Prop_Data, "m_iFrags", GetClientFrags(gallina)+1);
		new olddeaths = GetEntProp(gallina, Prop_Data, "m_iDeaths");
		SetEntProp(gallina, Prop_Data, "m_iDeaths", olddeaths-1);
	        new Float:Pos[3];
		GetEntPropVector(gallina, Prop_Send, "m_vecOrigin", Pos);
		CS_RespawnPlayer(gallina);
		TeleportEntity(gallina, Pos, NULL_VECTOR, NULL_VECTOR);
		ForcePlayerSuicide(gallina);

	}
}

QuitarGallina2()
{
	if(clientevalido(gallina))
		CS_RespawnPlayer(gallina);

}

//From SMLIB
stock Entity_SetParent(entity, parentEntity)
{
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", parentEntity);
}
