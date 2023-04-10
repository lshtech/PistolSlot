class X2StrategyElement_WOTC_PistolSlot extends CHItemSlotSet config (PistolSlot);

var localized string strPistolFirstLetter;

struct SlotStruct
{
	var name SOLDIER_CLASS;
	var name SOLDIER_ABILITY;
	var name WEAPON_CAT;
	var name TEMPLATE_NAME;
	var bool ALLOW_EMPTY;
};

var config array<SlotStruct> ADD_SLOT;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
	Templates.AddItem(CreatePistolSlotTemplate());
	return Templates;
}

static function X2DataTemplate CreatePistolSlotTemplate()
{
	local CHItemSlot Template;

	`CREATE_X2TEMPLATE(class'CHItemSlot', Template, 'PistolSlot');

	Template.InvSlot = eInvSlot_Pistol;
	Template.SlotCatMask = Template.SLOT_WEAPON | Template.SLOT_ITEM;
	// Unused for now
	Template.IsUserEquipSlot = true;
	// Uses unique rule
	Template.IsEquippedSlot = false;
	// Does not bypass unique rule
	Template.BypassesUniqueRule = false;
	Template.IsMultiItemSlot = false;
	Template.IsSmallSlot = false;
	Template.NeedsPresEquip = true;
	Template.ShowOnCinematicPawns = true;

	Template.CanAddItemToSlotFn = CanAddItemToPistolSlot;
	Template.UnitHasSlotFn = HasPistolSlot;
	Template.GetPriorityFn = PistolSlotGetPriority;
	Template.ShowItemInLockerListFn = ShowItemInLockerList;
	Template.ValidateLoadoutFn = PistolSlotValidateLoadout;
	Template.GetSlotUnequipBehaviorFn = PistolSlotGetUnequipBehavior;
	Template.GetDisplayLetterFn = GetPistolSlotDisplayLetter;
	//Template.GetBestGearForSlotFn = GetBestGearForPistolSlot;

	return Template;
}

static function bool HasPistolSlot(CHItemSlot Slot, XComGameState_Unit UnitState, out string LockedReason, optional XComGameState CheckGameState)
{    
    return IsAtLeastOneEntryRelevantForUnitState(UnitState);
}

static function bool ShowItemInLockerList(CHItemSlot Slot, XComGameState_Unit Unit, XComGameState_Item ItemState, X2ItemTemplate ItemTemplate, XComGameState CheckGameState)
{	;
	return IsItemTemplateAllowedForUnitState(ItemTemplate, Unit);
}

static function bool CanAddItemToPistolSlot(CHItemSlot Slot, XComGameState_Unit UnitState, X2ItemTemplate ItemTemplate, optional XComGameState CheckGameState, optional int Quantity = 1, optional XComGameState_Item ItemState)
{    
	//	If there is no item in the slot
	if(UnitState.GetItemInSlot(Slot.InvSlot, CheckGameState) == none)
	{
		return IsItemTemplateAllowedForUnitState(ItemTemplate, UnitState);
	}

	//	Slot is already occupied, cannot add any more items to it.
	return false;
}

static function PistolSlotValidateLoadout(CHItemSlot Slot, XComGameState_Unit Unit, XComGameState_HeadquartersXCom XComHQ, XComGameState NewGameState)
{
	local XComGameState_Item ItemState;
	local string strDummy;
	local bool HasSlot;
	local bool AllowEmpty;

	ItemState = Unit.GetItemInSlot(Slot.InvSlot, NewGameState);
	HasSlot = Slot.UnitHasSlot(Unit, strDummy, NewGameState);
	AllowEmpty = Slot.GetSlotUnequipBehaviorFn(Slot, eCHSUB_AllowEmpty, Unit, none) == eCHSUB_AllowEmpty;
	
	if(ItemState == none && HasSlot && !AllowEmpty)
	{
		ItemState = FindBestWeapon(Unit, XComHQ, NewGameState);
		if (ItemState != none)
		{
			`LOG("Empty slot is not allowed, equipping:" @ ItemState.GetMyTemplateName(),, 'WOTC_PistolSlot');
			if (Unit.AddItemToInventory(ItemState, eInvSlot_Pistol, NewGameState))
			{
				`LOG("Equipped successfully!",, 'WOTC_PistolSlot');
			}
			else `LOG("WARNING, could not equip it!",, 'WOTC_PistolSlot');
			return;
		}
		else `LOG("Empty slot is not allowed, but the mod was unable to find an infinite item to fill the slot.",, 'WOTC_PistolSlot');
	}	

	if(ItemState != none && !HasSlot)
	{
		`LOG("WARNING Unit:" @ Unit.GetFullName() @ "soldier class:" @ Unit.GetSoldierClassTemplateName() @ "has an item equipped in the Pistol Slot:" @ ItemState.GetMyTemplateName() @ ", but they are not supposed to have the Pistol Slot. Attempting to unequip the item.",, 'WOTC_PistolSlot');
		ItemState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', ItemState.ObjectID));
		if (Unit.RemoveItemFromInventory(ItemState, NewGameState))
		{
			`LOG("Successfully unequipped the item. Putting it into HQ Inventory.",, 'WOTC_PistolSlot');
			XComHQ.PutItemInInventory(NewGameState, ItemState);
		}
		else `LOG("WARNING, failed to unequip the item!",, 'WOTC_PistolSlot');
	}
}


private static function XComGameState_Item FindBestWeapon(const XComGameState_Unit UnitState, XComGameState_HeadquartersXCom XComHQ, XComGameState NewGameState)
{
	local X2ItemTemplate					ItemTemplate;
	local XComGameStateHistory				History;
	local int								HighestTier;
	local XComGameState_Item				ItemState;
	local XComGameState_Item				BestItemState;
	local StateObjectReference				ItemRef;
	local array<SlotStruct>					RelevantEntries;

	HighestTier = -999;
	History = `XCOMHISTORY;
	RelevantEntries = GatherRelevantEntriesForUnitState(UnitState);

	if (RelevantEntries.Length == 0)
	{
		`LOG("FindBestWeapon: ERROR, Unit:" @ UnitState.GetFullName() @ "has no relevant config entries, they're not supposed to have the slot!",, 'WOTC_PistolSlot');
		return none;
	}

	//	Cycle through all items in HQ Inventory
	foreach XComHQ.Inventory(ItemRef)
	{
		ItemState = XComGameState_Item(History.GetGameStateForObjectID(ItemRef.ObjectID));
		if (ItemState != none)
		{
			ItemTemplate = ItemState.GetMyTemplate();

			//	If this is an infinite item, it's tier is higher than the current recorded highest tier,
			//	it is allowed on the soldier by config entries that are relevant to this soldier
			//	and it can be equipped on the soldier
			if (ItemTemplate != none && ItemTemplate.bInfiniteItem && ItemTemplate.Tier > HighestTier && 
				IsItemAllowedByEntries(RelevantEntries, ItemTemplate) && 
				UnitState.CanAddItemToInventory(ItemTemplate, eInvSlot_Pistol, NewGameState, ItemState.Quantity, ItemState))
			{	
				//	then remember this item as the currently best replacement option.
				HighestTier = ItemTemplate.Tier;
				BestItemState = ItemState;
			}
		}
	}

	if (BestItemState != none)
	{
		//	This will set up the Item State for modification automatically, or create a new Item State in the NewGameState if the template is infinite.
		XComHQ.GetItemFromInventory(NewGameState, BestItemState.GetReference(), BestItemState);
	}

	//	If we didn't find any fitting items, then BestItemState will be "none", and we're okay with that.
	return BestItemState;
}

function ECHSlotUnequipBehavior PistolSlotGetUnequipBehavior(CHItemSlot Slot, ECHSlotUnequipBehavior DefaultBehavior, XComGameState_Unit UnitState, XComGameState_Item ItemState, optional XComGameState CheckGameState)
{	
	local array<SlotStruct> RelevantEntries;
	local SlotStruct		ArrayEntry;

	RelevantEntries = GatherRelevantEntriesForUnitState(UnitState);
	
	//	Cycle through all entries relevant to this unit.
	foreach RelevantEntries(ArrayEntry)
	{
		//	If at least one entry does not allow the slot to be empty
		if (!ArrayEntry.ALLOW_EMPTY)
		{
			//	Then we say the slot cannot be empty.
			return eCHSUB_AttemptReEquip;
		}
	}
	//	We have cycled through the whole array and all entries allow the slot to be empty.
	//	Or the array contains no members, but in this case the unit would not even have the slot, so we don't care about that scenario.
	return eCHSUB_AllowEmpty;
}

static function int PistolSlotGetPriority(CHItemSlot Slot, XComGameState_Unit UnitState, optional XComGameState CheckGameState)
{
	return 45; // Ammo Pocket is 110 
}

static function string GetPistolSlotDisplayLetter(CHItemSlot Slot)
{
	return default.strPistolFirstLetter;
}


//	======================================================
//			INTERFACE FUNCTIONS
//	======================================================

//	Cycle through the config array and return the array of functions according to which the soldier has the Pistol Slot.
static function array<SlotStruct> GatherRelevantEntriesForUnitState(const XComGameState_Unit UnitState)
{
	local array<SlotStruct> ReturnArray;
	local SlotStruct		ArrayEntry;
	local name				ClassTemplateName;
	
	ClassTemplateName = UnitState.GetSoldierClassTemplateName();
	
	//	Cycle through all entries in the config array
	foreach default.ADD_SLOT(ArrayEntry)
	{
		if (IsEntryRelevantForUnitState(ArrayEntry, UnitState, ClassTemplateName))
		{
			//	Add this entry to the array.
			ReturnArray.AddItem(ArrayEntry);
		}
	}
	return ReturnArray;
}

//	Check if the specified unit matches the parameters specified in the specified entry.
static function bool IsEntryRelevantForUnitState(const SlotStruct ArrayEntry, const XComGameState_Unit UnitState, const name ClassTemplateName)
{
	//	If this entry does not specify neither soldier class nor a soldier ability
	if (ArrayEntry.SOLDIER_CLASS == '' && ArrayEntry.SOLDIER_ABILITY == '')
	{
		//	Then we ignore it.
		return false;
	}

	//	If this entry specifies a soldier class name, and the soldier class name of this unit does not match...
	if (ArrayEntry.SOLDIER_CLASS != '' && ArrayEntry.SOLDIER_CLASS != ClassTemplateName) 
	{
		//	Then this entry is not relevant.
		return false;
	}

	//	If this entry specifies a soldier ability, and this unit does not have it...
	if (ArrayEntry.SOLDIER_ABILITY != '' && !UnitState.HasSoldierAbility(ArrayEntry.SOLDIER_ABILITY, true))
	{
		//	Then this entry is not relevant.
		return false;
	}

	//	This entry has passed all checks and is assumed relevant.
	return true;
}

//	Similar to GatherRelevantEntriesForUnitState, but we stop the moment we find at least one relevant entry for superior performance.
static function bool IsAtLeastOneEntryRelevantForUnitState(const XComGameState_Unit UnitState)
{
	local SlotStruct		ArrayEntry;
	local name				ClassTemplateName;
	
	ClassTemplateName = UnitState.GetSoldierClassTemplateName();
	
	//	Cycle through all entries in the config array
	foreach default.ADD_SLOT(ArrayEntry)
	{
		if (IsEntryRelevantForUnitState(ArrayEntry, UnitState, ClassTemplateName))
		{
			//	Return true if at least one entry is relevant.
			return true;
		}
	}
	//	If we cycled through the whole config array and did not find even one relevant entry.
	return false;
}

static function bool IsItemTemplateAllowedForUnitState(const X2ItemTemplate ItemTemplate, const XComGameState_Unit UnitState)
{
	local array<SlotStruct> RelevantEntries;
	local SlotStruct		ArrayEntry;
	local X2WeaponTemplate	WeaponTemplate;
	local name				WeaponCat;

	if (ItemTemplate.Name == 'None')
		return false;

	//	If this item is a weapon
	WeaponTemplate = X2WeaponTemplate(ItemTemplate);
	if (WeaponTemplate != none)
	{
		//	If this is a primary version added by Primary Secondaries, then it's not allowed.
		if (WeaponTemplate.InventorySlot == eInvSlot_PrimaryWeapon && WeaponTemplate.StowedLocation == eSlot_None)
		{
			return false;
		}

		//	Otherwise, record its Weapon Category.
		WeaponCat = WeaponTemplate.WeaponCat;
	}

	RelevantEntries = GatherRelevantEntriesForUnitState(UnitState);

	foreach RelevantEntries(ArrayEntry)
	{
		//	Check the weapon cat first, because it's more likely to succeed.
		//	This entry allows this weapon by weapon category.
		//	This check will automatically validate that WeaponCat != ''.
		if (ArrayEntry.WEAPON_CAT != '' && ArrayEntry.WEAPON_CAT == WeaponCat)
		{
			return true;
		}

		//	This entry allows this item by template name.
		if (ArrayEntry.TEMPLATE_NAME == ItemTemplate.DataName)
		{
			return true;
		}

		//	Checking for BOTH Template Name and WeaponCat is redundant, so we don't do that.
	}

	//	We have cycled through all relevant entries, and this item was not allowed by any of them.
	//	Or there were no relevant entries.
	return false;
}

static function bool IsItemAllowedByEntry(const SlotStruct ArrayEntry, const X2ItemTemplate ItemTemplate)
{
	local X2WeaponTemplate	WeaponTemplate;

	//	If this entry specifies an item template name and it matches the template name of the item.
	if (ArrayEntry.TEMPLATE_NAME != '' && ArrayEntry.TEMPLATE_NAME == ItemTemplate.DataName)
	{
		//	Then this item is allowed.
		return true;
	}

	//	If this entry specifies a weapon cat
	if (ArrayEntry.WEAPON_CAT != '')
	{
		WeaponTemplate = X2WeaponTemplate(ItemTemplate);
		
		//	And this item is a weapon with a matching Weeapon Cat
		if (WeaponTemplate != none && ArrayEntry.WEAPON_CAT == WeaponTemplate.WeaponCat)
		{
			//	Then this weapon is allowed.
			return true;
		}
	}

	//	This item does not fit the specified paramaters.
	return false;
}

static function bool IsItemAllowedByEntries(const array<SlotStruct> RelevantEntries, const X2ItemTemplate ItemTemplate)
{
	local SlotStruct ArrayEntry;

	//	Cycle through the given array of entries
	foreach RelevantEntries(ArrayEntry)
	{
		//	If at least one of them allows the item
		if (IsItemAllowedByEntry(ArrayEntry, ItemTemplate))
		{
			//	Then the item is allowed.
			return true;
		}
	}
	//	None of the entries allow the item.
	return false;
}