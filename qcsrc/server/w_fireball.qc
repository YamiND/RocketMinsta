.float bot_secondary_fireballmooth; // whatever a mooth is
.vector fireball_impactvec;
.float fireball_secondarytime;

void W_Fireball_Explode (void)
{
	entity e;
	float dist;
	float points;
	vector dir;
	float d;

	self.event_damage = SUB_Null;
	self.takedamage = DAMAGE_NO;

	// 1. dist damage
	d = (self.owner.health + self.owner.armorvalue);
	RadiusDamage (self, self.realowner, CVAR(g_balance_fireball_secondary_damage), CVAR(g_balance_fireball_secondary_edgedamage), CVAR(g_balance_fireball_secondary_radius), world, CVAR(g_balance_fireball_secondary_force), self.projectiledeathtype, other);
	if(self.realowner.health + self.realowner.armorvalue >= d)
	if(!self.cnt)
	{
		modeleffect_spawn("models/sphere/sphere.md3", 0, 0, self.origin, '0 0 0', '0 0 0', '0 0 0', 0, CVAR(g_balance_fireball_secondary_bfgradius), 0.2, 0.05, 0.25);

		// 2. bfg effect
		for(e = findradius(self.origin, CVAR(g_balance_fireball_secondary_bfgradius)); e; e = e.chain)
		if(e != self.owner) if(e.takedamage == DAMAGE_AIM) if(e.classname != "player" || !self.owner || IsDifferentTeam(e, self))
		{
			// can we see fireball?
			traceline(e.origin + e.view_ofs, self.origin, MOVE_NORMAL, e);
			if(/* trace_startsolid || */ trace_fraction != 1) // startsolid should be never happening anyway
				continue;
			// can we see player who shot fireball?
			traceline(e.origin + e.view_ofs, self.realowner.origin + self.realowner.view_ofs, MOVE_NORMAL, e);
			if(trace_ent != self.realowner)
			if(/* trace_startsolid || */ trace_fraction != 1)
				continue;
			dist = vlen(self.origin - e.origin - e.view_ofs);
			points = (1 - sqrt(dist / CVAR(g_balance_fireball_secondary_bfgradius)));
			if(points <= 0)
				continue;
			dir = normalize(e.origin + e.view_ofs - self.origin);
			Damage(e, self, self.realowner, CVAR(g_balance_fireball_secondary_bfgdamage) * points, self.projectiledeathtype | HITTYPE_BOUNCE | HITTYPE_SPLASH, e.origin + e.view_ofs, CVAR(g_balance_fireball_secondary_bfgforce) * dir);
			pointparticles(particleeffectnum("fireball_bfgdamage"), e.origin, -1 * dir, 1);

			Damage_RecordDamage(self.owner, self.projectiledeathtype, CVAR(g_balance_fireball_secondary_bfgdamage) * points);
		}
	}

	remove (self);
}

void W_Fireball_TouchExplode (void)
{
	PROJECTILE_TOUCH;
	W_Fireball_Explode ();
}

void W_Fireball_LaserPlay(float dt, float dist, float damage, float edgedamage, float burntime)
{
	entity e;
	float d;
	vector p;

	RandomSelection_Init();
	for(e = findradius(self.origin, dist); e; e = e.chain)
	if(e != self.owner) if(e.takedamage == DAMAGE_AIM) if(e.classname != "player" || !self.owner || IsDifferentTeam(e, self))
	{
		p = e.origin;
		p_x += e.mins_x + random() * (e.maxs_x - e.mins_x);
		p_y += e.mins_y + random() * (e.maxs_y - e.mins_y);
		p_z += e.mins_z + random() * (e.maxs_z - e.mins_z);
		d = vlen(self.origin - p);
		if(d < dist)
		{
			traceline(p, self.origin, MOVE_NORMAL, e);
			if(/* trace_startsolid || */ trace_fraction != 1)
				continue;
			e.fireball_impactvec = p;
			RandomSelection_Add(e, 0, NULL, 1 / (1 + d), !Fire_IsBurning(e));
		}
	}
	if(RandomSelection_chosen_ent)
	{
		d = vlen(self.origin - RandomSelection_chosen_ent.fireball_impactvec);
		d = damage + (edgedamage - damage) * (d / dist);
		Fire_AddDamage(RandomSelection_chosen_ent, self.realowner, d * burntime, burntime, self.projectiledeathtype | HITTYPE_BOUNCE);
		//trailparticles(self, particleeffectnum("fireball_laser"), self.origin, RandomSelection_chosen_ent.fireball_impactvec);
		pointparticles(particleeffectnum("fireball_laser"), self.origin, RandomSelection_chosen_ent.fireball_impactvec - self.origin, 1);
	}
}

void W_Fireball_Think()
{
	if(time > self.pushltime)
	{
		self.cnt = 1;
		W_Fireball_Explode();
		return;
	}

	W_Fireball_LaserPlay(0.1, CVAR(g_balance_fireball_secondary_laserradius), CVAR(g_balance_fireball_secondary_laserdamage), CVAR(g_balance_fireball_secondary_laseredgedamage), CVAR(g_balance_fireball_secondary_laserburntime));

	self.nextthink = time + 0.1;
}

void W_Fireball_Damage (entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force)
{
	if(self.health <= 0)
		return;
	self.health = self.health - damage;
	if (self.health <= 0)
	{
		self.cnt = 1;
		W_PrepareExplosionByDamage(attacker, W_Fireball_Explode);
	}
}

void W_Fireball_Attack2()
{
	entity proj;

	W_SetupShot_ProjectileSize (self, '-16 -16 -16', '16 16 16', FALSE, 2, "weapons/fireball_fire2.wav", CVAR(g_balance_fireball_secondary_damage) + CVAR(g_balance_fireball_secondary_bfgdamage));

	pointparticles(particleeffectnum("fireball_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);

	proj = spawn ();
	proj.classname = "plasma_prim";
	proj.owner = proj.realowner = self;
	proj.bot_dodge = TRUE;
	proj.bot_dodgerating = CVAR(g_balance_fireball_secondary_damage);
	proj.pushltime = time + CVAR(g_balance_fireball_secondary_lifetime);
	proj.use = W_Fireball_Explode;
	proj.think = W_Fireball_Think;
	proj.nextthink = time;
	proj.health = CVAR(g_balance_fireball_secondary_health);
	proj.team = self.team;
	proj.event_damage = W_Fireball_Damage;
	proj.takedamage = DAMAGE_YES;
	proj.damageforcescale = CVAR(g_balance_fireball_secondary_damageforcescale);
	PROJECTILE_MAKETRIGGER(proj);
	proj.projectiledeathtype = WEP_FIREBALL | HITTYPE_SECONDARY;
	setorigin(proj, w_shotorg);

	proj.movetype = MOVETYPE_FLY;
	proj.velocity = w_shotdir * CVAR(g_balance_fireball_secondary_speed);
	W_SetupProjectileVelocity(proj);
	proj.angles = vectoangles(proj.velocity);
	proj.touch = W_Fireball_TouchExplode;
	setsize(proj, '-16 -16 -16', '16 16 16');
	proj.flags = FL_PROJECTILE;
    
	CSQCProjectile(proj, TRUE, PROJECTILE_FIREBALL, TRUE);
}

void W_Fireball_AttackEffect(float i, vector f_diff)
{
	W_SetupShot_ProjectileSize (self, '-16 -16 -16', '16 16 16', FALSE, 0, "", 0);
	w_shotorg += f_diff_x * v_up + f_diff_y * v_right;
	pointparticles(particleeffectnum("fireball_preattack_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);
}

void W_Fireball_Attack2_Frame4()
{
    if(!PlayerMayFire(self)) {
        w_ready();
        return;
    }

	W_Fireball_Attack2();
	weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_fireball_secondary_animtime), w_ready);
}

void W_Fireball_Attack2_Frame3()
{
	W_Fireball_AttackEffect(0, '+1.25 +3.75 0');
	weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_fireball_secondary_animtime), W_Fireball_Attack2_Frame4);
}

void W_Fireball_Attack2_Frame2()
{
	W_Fireball_AttackEffect(0, '-1.25 +3.75 0');
	weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_fireball_secondary_animtime), W_Fireball_Attack2_Frame3);
}

void W_Fireball_Attack2_Frame1()
{
	W_Fireball_AttackEffect(1, '+1.25 -3.75 0');
	weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_fireball_secondary_animtime), W_Fireball_Attack2_Frame2);
}

void W_Fireball_Attack2_Frame0()
{
    float cost = CVAR(g_balance_fireball_secondary_ammo);

    if(!W_Clip_Consume(cost))
        return;

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
		self.ammo_rockets -= cost;

	W_Fireball_AttackEffect(0, '-1.25 -3.75 0');
	sound (self, CHAN_WEAPON, "weapons/fireball_prefire2.wav", VOL_BASE, ATTN_NORM);
	weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_fireball_secondary_animtime), W_Fireball_Attack2_Frame1);
}

void W_Firemine_Think()
{
	if(time > self.pushltime)
	{
		remove(self);
		return;
	}

	// make it "hot" once it leaves its owner
	if(self.owner)
	{
		if(vlen(self.origin - self.owner.origin - self.owner.view_ofs) > CVAR(g_balance_fireball_primary_laserradius))
		{
			self.cnt += 1;
			if(self.cnt == 3)
				self.owner = world;
		}
		else
			self.cnt = 0;
	}

	W_Fireball_LaserPlay(0.1, CVAR(g_balance_fireball_primary_laserradius), CVAR(g_balance_fireball_primary_laserdamage), CVAR(g_balance_fireball_primary_laseredgedamage), CVAR(g_balance_fireball_primary_laserburntime));

	self.nextthink = time + 0.1;
}

void W_Firemine_Touch (void)
{
	PROJECTILE_TOUCH;
	if (other.takedamage == DAMAGE_AIM)
	if(Fire_AddDamage(other, self.realowner, CVAR(g_balance_fireball_primary_damage), CVAR(g_balance_fireball_primary_damagetime), self.projectiledeathtype | HITTYPE_HEADSHOT) >= 0)
	{
		remove(self);
		return;
	}
	self.projectiledeathtype |= HITTYPE_BOUNCE;
}

void W_Fireball_Attack1()
{
	entity proj;
	vector f_diff;
	float c;
    float cost = CVAR(g_balance_fireball_primary_ammo);

    if(!W_Clip_Consume(cost))
        return;

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
		self.ammo_rockets -= cost;

	c = mod(self.bulletcounter, 4);
	switch(c)
	{
		case 0:
			f_diff = '-1.25 -3.75 0';
			break;
		case 1:
			f_diff = '+1.25 -3.75 0';
			break;
		case 2:
			f_diff = '-1.25 +3.75 0';
			break;
		case 3:
		default:
			f_diff = '+1.25 +3.75 0';
			break;
	}
	W_SetupShot_ProjectileSize(self, '-4 -4 -4', '4 4 4', FALSE, 2, "weapons/fireball_fire.wav", CVAR(g_balance_fireball_primary_damage));
	traceline(w_shotorg, w_shotorg + f_diff_x * v_up + f_diff_y * v_right, MOVE_NORMAL, self);
	w_shotorg = trace_endpos;

	pointparticles(particleeffectnum("fireball_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);

	proj = spawn ();
	proj.owner = proj.realowner = self;
	proj.classname = "grenade";
	proj.bot_dodge = TRUE;
	proj.bot_dodgerating = CVAR(g_balance_fireball_primary_damage);
	proj.movetype = MOVETYPE_BOUNCE;
	proj.projectiledeathtype = WEP_FIREBALL;
	proj.touch = W_Firemine_Touch;
	PROJECTILE_MAKETRIGGER(proj);
	setsize(proj, '-4 -4 -4', '4 4 4');
	setorigin(proj, w_shotorg);
	proj.think = W_Firemine_Think;
	proj.nextthink = time;
	proj.damageforcescale = CVAR(g_balance_fireball_primary_damageforcescale);
	proj.velocity = w_shotdir * CVAR(g_balance_fireball_primary_speed) + v_up * CVAR(g_balance_fireball_primary_speed_up);
	proj.pushltime = time + CVAR(g_balance_fireball_primary_lifetime);
	W_SetupProjectileVelocity(proj);

	proj.angles = vectoangles(proj.velocity);
	proj.flags = FL_PROJECTILE;

	CSQCProjectile(proj, TRUE, PROJECTILE_FIREMINE, TRUE);
}

void spawnfunc_weapon_fireball (void)
{
	weapon_defaultspawnfunc(WEP_FIREBALL);
}

void W_Fireball_SetClipContext(void) {
    W_Clip_SetWeaponContext(
        WEP_FIREBALL,
        CVAR(g_balance_fireball_magazinecapacity),
        CVAR(g_balance_fireball_magazineregen),
        CVAR(g_balance_fireball_reloadtime),
        ammo_rockets,
        1
    );
}

float w_fireball(float req)
{
    W_SetButtonFields(self, CVAR(g_balance_fireball_swapshotmodes));
    W_Fireball_SetClipContext();

	if (req == WR_AIM)
	{
		self.w_button_primary = FALSE;
		self.w_button_secondary = FALSE;
		if (self.bot_secondary_fireballmooth == 0)
		{
			if(bot_aim(CVAR(g_balance_fireball_primary_speed), CVAR(g_balance_fireball_primary_speed_up), CVAR(g_balance_fireball_primary_lifetime), TRUE))
			{
				self.w_button_primary = TRUE;
				if(random() < 0.01) self.bot_secondary_fireballmooth = 1;
			}
		}
		else
		{
			if(bot_aim(CVAR(g_balance_fireball_secondary_speed), 0, CVAR(g_balance_fireball_secondary_lifetime), FALSE))
			{
				self.w_button_secondary = TRUE;
				if(random() < 0.02) self.bot_secondary_fireballmooth = 0;
			}
		}
	}
	else if (req == WR_THINK)
	{
        if(W_Clip_TryWeaponAction()) {
            if(self.w_button_primary)
            if(weapon_prepareattack(0, CVAR(g_balance_fireball_primary_refire)))
            if(W_Clip_TryAttackOrReload()) {
                W_Fireball_Attack1();
                weapon_thinkf(WFRAME_FIRE2, CVAR(g_balance_fireball_primary_animtime), w_ready);
            }

            if(self.w_button_secondary)
            if(time >= self.fireball_secondarytime)
            if(weapon_prepareattack(1, CVAR(g_balance_fireball_secondary_refire)))
            if(W_Clip_TryAttackOrReload()) {
                W_Fireball_Attack2_Frame0();
                self.fireball_secondarytime = time + CVAR(g_balance_fireball_secondary_refire2);
            }

            W_Clip_FinishWeaponAction();
        }
	}
	else if (req == WR_PRECACHE)
	{
		precache_model ("models/sphere/sphere.md3");
		precache_sound ("weapons/fireball_fire.wav");
		precache_sound ("weapons/fireball_fire2.wav");
		precache_sound ("weapons/fireball_prefire2.wav");
	}
	else if (req == WR_SETUP)
		weapon_setup(WEP_FIREBALL);
	else if (req == WR_CHECKAMMO1)
		return self.ammo_rockets >= CVAR(g_balance_fireball_primary_ammo);
	else if (req == WR_CHECKAMMO2)
		return self.ammo_rockets >= CVAR(g_balance_fireball_secondary_ammo);
	else if (req == WR_RESETPLAYER)
	{
		self.fireball_secondarytime = time;
	}
    else if (req == WR_TT_STORE)
    {
        TimeTravel_StoreTime(self,      tt_moment, fireball_secondarytime);
    }
    else if (req == WR_TT_RESTORE)
    {
        TimeTravel_RestoreTime(self,    tt_moment, fireball_secondarytime);
    }

    W_Clip_WeaponRequestHook(req);
	return TRUE;
};
