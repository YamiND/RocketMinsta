.float dmg;
.float dmg_edge;
.float dmg_radius;
.float dmg_force;
.float dmg_power;
.float dmg_duration;
.float dmg_last;
.float hook_refire;
.float hook_time_hooked;
.float hook_time_fueldecrease;

void W_Hook_ExplodeThink (void)
{
	float dt, dmg_remaining_next, f;

	dt = time - self.teleport_time;
	dmg_remaining_next = pow(bound(0, 1 - dt / self.dmg_duration, 1), self.dmg_power);

	f = self.dmg_last - dmg_remaining_next;
	self.dmg_last = dmg_remaining_next;

	RadiusDamage (self, self.owner, self.dmg * f, self.dmg_edge * f, self.dmg_radius, self.owner, self.dmg_force * f, self.projectiledeathtype, world);
	self.projectiledeathtype |= HITTYPE_BOUNCE;
	//RadiusDamage (self, world, self.dmg * f, self.dmg_edge * f, self.dmg_radius, world, self.dmg_force * f, self.projectiledeathtype, world);

	if(dt < self.dmg_duration)
		self.nextthink = time + 0.05; // soon
	else
		remove(self);
}

void W_Hook_Explode2 (void)
{
	self.event_damage = SUB_Null;
	self.touch = SUB_Null;
	self.effects |= EF_NODRAW;

	self.think = W_Hook_ExplodeThink;
	self.nextthink = time;
	self.dmg = CVAR(g_balance_hook_secondary_damage);
	self.dmg_edge = CVAR(g_balance_hook_secondary_edgedamage);
	self.dmg_radius = CVAR(g_balance_hook_secondary_radius);
	self.dmg_force = CVAR(g_balance_hook_secondary_force);
	self.dmg_power = CVAR(g_balance_hook_secondary_power);
	self.dmg_duration = CVAR(g_balance_hook_secondary_duration);
	self.teleport_time = time;
	self.dmg_last = 1;
	self.movetype = MOVETYPE_NONE;
}

void W_Hook_Touch2 (void)
{
	PROJECTILE_TOUCH;
	self.use();
}

void W_Hook_Attack2()
{
	entity gren;

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
		self.ammo_cells = self.ammo_cells - CVAR(g_balance_hook_secondary_ammo);
	W_SetupShot (self, FALSE, 4, "weapons/hookbomb_fire.wav", CVAR(g_balance_hook_secondary_damage));

	gren = spawn ();
	gren.owner = self;
	gren.classname = "hookbomb";
	gren.bot_dodge = TRUE;
	gren.bot_dodgerating = CVAR(g_balance_hook_secondary_damage);
	gren.movetype = MOVETYPE_TOSS;
	PROJECTILE_MAKETRIGGER(gren);
	gren.projectiledeathtype = WEP_HOOK | HITTYPE_SECONDARY;
	setorigin(gren, w_shotorg);
	setsize(gren, '0 0 0', '0 0 0');

	gren.nextthink = time + CVAR(g_balance_hook_secondary_lifetime);
	gren.think = adaptor_think2use;
	gren.use = W_Hook_Explode2;
	gren.touch = W_Hook_Touch2;

	gren.velocity = '0 0 1' * CVAR(g_balance_hook_secondary_speed);
	if(CVAR(g_projectiles_newton_style))
		gren.velocity = gren.velocity + self.velocity;

	gren.gravity = CVAR(g_balance_hook_secondary_gravity);
	//W_SetupProjectileVelocity(gren); // just falling down!

	gren.angles = '0 0 0';
	gren.flags = FL_PROJECTILE;

	CSQCProjectile(gren, TRUE, PROJECTILE_HOOKBOMB, TRUE);
}

void spawnfunc_weapon_hook (void)
{
	if(g_grappling_hook) // offhand hook
	{
		startitem_failed = TRUE;
		remove(self);
		return;
	}
	weapon_defaultspawnfunc(WEP_HOOK);
}

float w_hook(float req)
{
    W_SetButtonFields(self, CVAR(g_balance_grapplehook_swapshotmodes));
	float hooked_time_max, hooked_fuel;
		
	if (req == WR_AIM)
	{
		// ... sorry ...
	}
	else if (req == WR_THINK)
	{
		if (self.w_button_primary || (!(self.items & IT_JETPACK) && self.BUTTON_HOOK))
		{
			if(!self.hook)
			if not(self.hook_state & HOOK_WAITING_FOR_RELEASE)
			if not(self.hook_state & HOOK_FIRING)
			if (time > self.hook_refire)
			if (weapon_prepareattack(0, -1))
			{
				if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
					self.ammo_fuel = self.ammo_fuel - CVAR(g_balance_hook_primary_fuel);
				self.hook_state |= HOOK_FIRING;
				weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_hook_primary_animtime), w_ready);				
			}
		}

		if (self.w_button_secondary)
		{
			if (weapon_prepareattack(1, CVAR(g_balance_hook_secondary_refire)))
			{
				W_Hook_Attack2();
				weapon_thinkf(WFRAME_FIRE2, CVAR(g_balance_hook_secondary_animtime), w_ready);
			}
		}

		if(self.hook)
		{
			// if hooked, no bombs, and increase the timer
			self.hook_refire = max(self.hook_refire, time + CVAR(g_balance_hook_primary_refire));

			// hook also inhibits health regeneration, but only for 1 second
			if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
				self.pauseregen_finished = max(self.pauseregen_finished, time + CVAR(g_balance_pause_fuel_regen));
		}

		if(self.hook && self.hook.state == 1)
		{
			hooked_time_max = CVAR(g_balance_hook_primary_hooked_time_max);			
			if (hooked_time_max > 0)
			{
				if ( time > self.hook_time_hooked + hooked_time_max )
					self.hook_state |= HOOK_REMOVING;
			}
			
			hooked_fuel = CVAR(g_balance_hook_primary_hooked_fuel);
			if (hooked_fuel > 0)
			{
				if ( time > self.hook_time_fueldecrease )
				{
					if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
					{
						if ( self.ammo_fuel >= (time - self.hook_time_fueldecrease) * hooked_fuel )
						{
							self.ammo_fuel -= (time - self.hook_time_fueldecrease) * hooked_fuel;
							self.hook_time_fueldecrease = time;
							// decrease next frame again
						}
						else
						{
							self.ammo_fuel = 0;
							self.hook_state |= HOOK_REMOVING;
							W_SwitchWeapon_OutOfAmmo(self);
						}
					}
				}
			}
		}
		else
		{
			self.hook_time_hooked = time;				
			self.hook_time_fueldecrease = time + CVAR(g_balance_hook_primary_hooked_time_free);
		}

		if (self.BUTTON_CROUCH)
		{
			self.hook_state &~= HOOK_PULLING;
			if (self.w_button_primary || (!(self.items & IT_JETPACK) && self.BUTTON_HOOK))
				self.hook_state &~= HOOK_RELEASING;
			else
				self.hook_state |= HOOK_RELEASING;
		}
		else
		{
			self.hook_state |= HOOK_PULLING;
			self.hook_state &~= HOOK_RELEASING;

			if (self.w_button_primary || (!(self.items & IT_JETPACK) && self.BUTTON_HOOK))
			{
				// already fired
				if(self.hook)
					self.hook_state |= HOOK_WAITING_FOR_RELEASE;
			}
			else
			{
				self.hook_state |= HOOK_REMOVING;
				self.hook_state &~= HOOK_WAITING_FOR_RELEASE;
			}
		}
	}
	else if (req == WR_PRECACHE)
	{
		precache_sound ("weapons/hook_impact.wav"); // done by g_hook.qc
		precache_sound ("weapons/hook_fire.wav");
		precache_sound ("weapons/hookbomb_fire.wav");
	}
	else if (req == WR_SETUP)
	{
		weapon_setup(WEP_HOOK);
		self.hook_state &~= HOOK_WAITING_FOR_RELEASE;
	}
	else if (req == WR_CHECKAMMO1)
	{
		if(self.hook)
			return self.ammo_fuel > 0;
		else
			return self.ammo_fuel >= CVAR(g_balance_hook_primary_fuel);
	}
	else if (req == WR_CHECKAMMO2)
	{
		return self.ammo_cells >= CVAR(g_balance_hook_secondary_ammo);
	}
	else if (req == WR_RESETPLAYER)
	{
		self.hook_refire = time;
	}
	return TRUE;
};
