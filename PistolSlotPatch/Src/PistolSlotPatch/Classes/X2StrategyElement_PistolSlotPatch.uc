class X2StrategyElement_PistolSlotPatch extends X2StrategyElement_WOTC_PistolSlot config (PistolSlot);

static function bool IsItemTemplateAllowedForUnitState(const X2ItemTemplate ItemTemplate, const XComGameState_Unit UnitState)
{
	if (ItemTemplate.Name == 'None')
		return false;

	return super.IsItemTemplateAllowedForUnitState(ItemTemplate, UnitState);
}
