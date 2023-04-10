//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_WotC_VestSlot.uc                                    
//           
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the 
//  player creates a new campaign or loads a saved game.
//  
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_WOTC_PistolSlot extends X2DownloadableContentInfo config(PistolSlot);

var config bool MULTIPLE_OVERWATCH_FIX;

//var config array<name> PistolCategories;

/// <summary>
/// This method is run if the player loads a saved game that was created prior to this DLC / Mod being installed, and allows the 
/// DLC / Mod to perform custom processing in response. This will only be called once the first time a player loads a save that was
/// create without the content installed. Subsequent saves will record that the content was installed.
/// </summary>
static event OnLoadedSavedGame()
{}

/// <summary>
/// Called when the player starts a new campaign while this DLC / Mod is installed
/// </summary>
static event InstallNewCampaign(XComGameState StartState)
{}


static function bool CanAddItemToInventory_CH_Improved(out int bCanAddItem, const EInventorySlot Slot, const X2ItemTemplate ItemTemplate, int Quantity, XComGameState_Unit UnitState, optional XComGameState CheckGameState, optional out string DisabledReason, optional XComGameState_Item ItemState)
{
    local name SoldierClassName;
    local X2WeaponTemplate WeaponTemplate;
	local name WeaponCat;
    local int i;

	// If game state code attempts to equip an item into the pistol slot while it's not empty, 
	// then exit function without doing anything, allowing the game to disallow equipping.
	if (Slot == eInvSlot_Pistol && CheckGameState != none && UnitState.GetItemInSlot(eInvSlot_Pistol, CheckGameState) != none)
	{
	return CheckGameState == none; // Do not override behavior
	}

    SoldierClassName = UnitState.GetSoldierClassTemplateName();
    WeaponTemplate = X2WeaponTemplate(ItemTemplate);

	if (WeaponTemplate != none)
	{
		WeaponCat = WeaponTemplate.WeaponCat;
	}

    for (i=0;i<class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT.Length;i++)
	{
		if (class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT[i].SOLDIER_CLASS != '' && SoldierClassName == class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT[i].SOLDIER_CLASS && 
		   (class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT[i].SOLDIER_ABILITY == '' || UnitState.HasSoldierAbility(class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT[i].SOLDIER_ABILITY, true)))
			//    If soldier's class matches the one specified in this array element, return true if this array element doesn't have a required ability specified,
			//    or if the soldier has the specified ability.
		{
			if (class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT[i].WEAPON_CAT != '' && WeaponCat == class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT[i].WEAPON_CAT || ItemTemplate.DataName == class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT[i].TEMPLATE_NAME)
			{
				if (Slot == eInvSlot_Pistol)
				{
					//    Allow the weapon to be equipped.
					DisabledReason = "";
					bCanAddItem = 1;
            
					//    Override normal behavior.
					return CheckGameState != none;
				}
			}
		}
		else
		{
			if (class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT[i].SOLDIER_CLASS == '' && class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT[i].SOLDIER_ABILITY != '' && UnitState.HasSoldierAbility(class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT[i].SOLDIER_ABILITY, true))
			{
				if (class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT[i].WEAPON_CAT != '' && WeaponCat == class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT[i].WEAPON_CAT || ItemTemplate.DataName == class'X2StrategyElement_WOTC_PistolSlot'.default.ADD_SLOT[i].TEMPLATE_NAME)
				{
					if (Slot == eInvSlot_Pistol)
					{
						//    Allow the weapon to be equipped.
						DisabledReason = "";
						bCanAddItem = 1;
            
						//    Override normal behavior.
						return CheckGameState != none;
					}
				}
			}
		}
	}
    //    Do not override normal behavior.
    return CheckGameState == none;
}


static event OnPostTemplatesCreated()
{
    local X2ItemTemplateManager       ItemMgr;
    local X2WeaponTemplate            Template;
    local array<X2WeaponTemplate>     Templates; 
	local X2AbilityTemplateManager    AbilityTemplateManager;
	local X2AbilityTemplate			  Ability;

	//Stuff's too clumped up here. Better implementation below.
	//class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate('PistolStandardShot').bUniqueSource = true;
	//class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate('PistolOverwatch').bUniqueSource = true;

	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	//Unique Pistol Standard Shot
	Ability = AbilityTemplateManager.FindAbilityTemplate('PistolStandardShot');
	Ability.bUniqueSource = true;

    ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
        
    Templates = ItemMgr.GetAllWeaponTemplates();
    
    foreach Templates(Template)
    {        
        if (Template.WeaponCat == 'pistol')
        {
            Template.Abilities.AddItem('PistolStandardShot');
        }
    }
	X2AbilityCost_QuickdrawActionPoints(class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate('PistolStandardShot').AbilityCosts[0]).DoNotConsumeAllSoldierAbilities.AddItem('Quickdraw');
}