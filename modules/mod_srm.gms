*------------------------------------------------------------------------
* Module Geoengineering by SRM via SO2 injection
* Additional changes required in mod_climate (* Total radiative forcing) and reg_model
* v2: for new mode, January 2015
*-------------------------------------------------------------------------

$ifthen.ph %phase%=='conf'

*Period in which SRM becomes available
$setglobal geoeng_start 2050
*if only one region is allowed to implement SRM
$setglobal only_region nde
*maximum amount of SRM per region (in MtS)
$setglobal maxsrm 2

*Activate damages from SRM
$setglobal damage_geoeng
$setglobal impsrm_exponent 2 #exponent of damage function
$setglobal damage_geoeng_amount 0.03


*------------------------------------------------------------------------
$elseif.ph %phase%=='sets'

set srm_available(t, n) 'periods and regions where SRM is available and used';

*------------------------------------------------------------------------
$elseif.ph %phase%=='include_data'

* In the phase INCLUDE_DATA you should declare and include all your exogenous parameters.
* You can also modify the data loaded in data.gms
* Best practice : - create a .gdx containing those and to loading it
*                 - this is the only phase where we should have numbers...

* Costs: 5 (Robock 2009) - 25 (Cruzen 2006) billion US/TgS
* Forcing: -0.5 (Cruzen 2006) up to -2.5 (Rasch 2008) W/m^2/TgS (see also Gramstad and Tjotta (2010)
* Atmospheric residence time: not relevant for dynamics due to 5 year time step, but lowers cost!
* 1Tg = 1MT. 1gr S = 2gr SO2
Parameters
                        srm_cost_tgs        'costs in billion USD per TgS'          / 10 /
                        geoeng_forcing          'negative forcing per TgS'          / -1.75 /
                        geoeng_residence_in_atm 'atmospheric residence time'            / 2 /
;
* compute actual cost per year taking into account the atmospheric residence time, disregarding initialisation.
* convert billions into T$ (trillions USD) by dividing by 1000.
*SRM_COST_tgs=(SRM_COST_tgs/geoeng_residence_in_atm)/1000 ;

parameter wsrm(t)     'World SRM SO2 injections';

parameter damage_geoeng_amount(n);
damage_geoeng_amount(n) = %damage_geoeng_amount%;


*------------------------------------------------------------------------
$elseif.ph %phase%=='compute_data'

*------------------------------------------------------------------------
$elseif.ph %phase%=='declare_vars'

Variable SRM(t,n) 'TgS injected into the atmosphere';
SRM.lo(t,n)=0;
*start from zero
SRM.l(t,n)=0;

*now instead randomize
$ifthen.rnd set randomsrminit
execseed = 1 + gmillisec(jnow);
parameter srm_init(n);
srm_init(n) = Uniform(0,0.5)
SRM.l(t,n) = srm_init(n);
$endif.rnd
$if set init_region SRM.l(t,'%init_region%')=2;

Variable SRM_COST(t,n)  'Costs of Geoengineering in trillion USD';

Variable W_SRM(t,n);
W_SRM.lo(t,n) = 0;


*------------------------------------------------------------------------
$elseif.ph %phase%=='compute_vars'
* The phase BEFORE_NASHLOOP is situated just before the loop solving an equilibrium

SRM.lo(t, n) = 0;

*determine by whom and when SRM is admissible
*only after 2050
srm_available(t,n)$(year(t) ge %geoeng_start%) = YES;
*now define that Geoengineering is only admissible in branch_1 and only for the USA:
*srm_available(t,n)$(not sameas(n, 'usa')) = NO;
$if set only_region srm_available(t,n)$(not sameas(n, '%only_region%')) = NO;

* To start with, no Geoengineering possible
SRM.fx(t, n)$(not srm_available(t,n))=0;
SRM.l(t, n)$(not srm_available(t,n))=0;
*W_SRM.fx(t, n)$(not srm_available(t,n))=0;

*everyone can do it (or limited Geoengineering to x<1 Tg per year)
SRM.up(t, n)$(srm_available(t,n))=%maxsrm%;



* recompute climate and damages based on the new W_SRM.l
wsrm(t) = sum(n, SRM.l(t,n));
W_SRM.l(t,n) =  wsrm(t);


*------------------------------------------------------------------------------
$elseif.ph %phase%=='eql'

* List of equations
eq_srm_cost
eqw_srm

*------------------------------------------------------------------------------
$elseif.ph %phase%=='eqs'

** Geoeng impacts from Goes et al 2011
eq_srm_cost(t,n)$(reg(n))..
                   SRM_COST(t, n) =e= ((srm_cost_tgs/geoeng_residence_in_atm)/1000) * (SRM(t, n)**%impsrm_exponent%);

eqw_srm(t,n)$(reg(n))..
                W_SRM(t,n) =e= wsrm(t) + sum(nn$reg(nn), SRM(t,nn) - SRM.l(t,nn));


*------------------------------------------------------------------------
$elseif.ph %phase%=='before_solve'

wsrm(t) = sum(n, SRM.l(t,n));
*------------------------------------------------------------------------
$elseif.ph %phase%=='after_nashloop'
* In the phase AFTER_NASHLOOP, you compute parameters needed for the report, once the job is ready.
* Best practice : - you should not declare parameters as this phase might be inside a loop

* recompute climate and damages based on the new W_SRM.l
wsrm(t) = sum(n, SRM.l(t,n));
W_SRM.l(t,n) =  wsrm(t);
*recompute climate module
$batinclude 'modules/hub_climate'

$elseif.ph %phase%=='gdx_items'
* List the items to be kept in the final gdx
SRM
SRM_COST
wsrm
W_SRM
srm_available

$endif.ph
