MultiMacro
========

A WoW addon that enables you to make macros with multiple spells (even for other classes/specializations), and have
the correct icon/cooldown for it.

Say you want to combine interrupts from different classes into a single macro to save macro slots:

    #showtooltip
    /cast Kick
    /cast Counterspell
    /cast Rebuke
    /run local G=GetSpellInfo SetMacroSpell(GetRunningMacro(), G"Kick" or G"Counterspell" or G"Rebuke")

The issue with this is you have to hit the spell to see the cooldown, and sometimes it would randomly reset and have a red question mark.

MultiMacro will parse your macros, check the availability of the used spells and set the correct icon/cooldown automatically:

    #showtooltip
    /cast Kick
    /cast Counterspell
    /cast Rebuke

It also allows you to omit #showtooltip value for items:

    #showtooltip
    /use 13

# Similar Addons

MegaMacro - this addon copies part of the MegaMacro functionality but omits all other features to make it more native and less likelly affected by the WoW updates.
