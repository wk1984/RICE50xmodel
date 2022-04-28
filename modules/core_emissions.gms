* EMISSIONS MODULE
*
* Where Regions emissions are determined.
*____________
#=========================================================================
*   ///////////////////////       SETTING      ///////////////////////
#=========================================================================
#
## CONF
#_________________________________________________________________________
* Definition of the global flags and settings specific to the module
$ifthen.ph %phase%=='conf'

* MIU linear-transition time horizon from 1 to maximum upperbound
$setglobal t_min_miu 9
$setglobal t_max_miu 38

* MIU maximum reacheable upperbound
$setglobal max_miuup 1.2

* Carbon-intensity transition curve
* | linear_pure | linear_soft | sigmoid_HHs | sigmoid_Hs | sigmoid_Ms | sigmoid_Ls | sigmoid_LLs |
$setglobal sig_trns_type 'sigmoid_Ls'

* Time of full-convergence to dice-ref carbon-intensity curve
* | 28 | 38 | 48 | 58 |
$setglobal sig_trns_end  '38'

* SSP-n hypothesis on dice-reference curve for carbon-intensity
* |original | discounted |
$setglobal sig_dice_ref_curve 'discounted'


## SETS
#_________________________________________________________________________
$elseif.ph %phase%=='sets'

SET ere 'Emissions-related entities'/
    co2
    co2ffi # Fossil-fuel and Industry CO2
    nip    # net import of permits
    sav    # saved permits
    kghg   # Kyoto greenhouse gases
    ch4
    n2o
    sf6
    #hfc
    #pfc
/;
ALIAS(ere,eere);

SET map_e(ere,eere) 'Relationships between Sectoral Emissions' /
    co2.co2ffi
/;

SET ghg(ere) 'Green-House Gases'
/
    co2
    ch4
    n2o
    #sf6
    #hfc
    #pfc
/;

SET oghg(ghg) 'Other GHGs'
/
    ch4
    n2o
    #sf6
    #hfc
    #pfc
/;

## INCLUDE DATA
#_________________________________________________________________________
$elseif.ph %phase%=='include_data'

# .......  PARAMETERS HARDCODED OR ASSIGNED  .......
PARAMETERS
* Cumulative emissions startings
   cumeind0   'Starting value of cumulative emissions from industry [GtC]'                 / 400   /  # DICE2016
   cumetree0  'Starting value of cumulative emissions from land use deforestation [GtC]'   / 100   /
* Availability of fossil fuels
   fosslim    'Maximum cumulative extraction fossil fuels (GtC)' / 6000 /
* MIU rate controls
   miu0       'Initial emissions control rate for base calib_emissions'    / 0 / 
   min_miu     'upper bound for control rate MIU at t_min_miu'       / 1.00 / # best compromise
   t_min_miu    'time t when min_miu value can be reached'           / %t_min_miu%    / # 7 - 2045
   max_miu     'upper bound for control rate MIU from t_max_miu'     / %max_miuup%  / # the old DICE limmiu
   t_max_miu    'time t when max_miu value can be reached'           / %t_max_miu%  / # 28 - 2150
   min_miuoghg 'upper bound for control rate MIU at t_min_miu'       / 0.7  / # best compromise
   max_miuoghg 'upper bound for control rate MIU from tmax'        / 1    / # best compromise
;

##  PARAMETERS EVALUATED ----------

SCALAR
* Conversion coefficients
   CtoCO2        'conversion factor from Carbon to CO2'
   CO2toC        'conversion factor from CO2 to Carbon'
;

## BAU EMISSIONS AND CARBON INTENSITY 
PARAMETERS
    ssp_emi_bau(ssp,t,n)   'SSP-Decline rate of decarbonization according to different scenarios (per period)'
    emi_bau_co2(t,n)       "Baseline regional CO2 FFI emissions [GtCO2]"
    sigma(t,n)                  'Decline rate of decarbonization (per period)'
    sig0(n)                     'Carbon intensity at starting time [kgCO2 per output 2005 USD]'
;

$gdxin '%datapath%data_baseline_emissions_calibrated.gdx'
$load   ssp_emi_bau=emi_bau_calibrated
$gdxin
* Configuration settings determine imported scenario
emi_bau_co2(t,n) = ssp_emi_bau('%baseline%',t,n)  ;

$ifthen.perma %permafrost% == 'pf'
## PERMAFROST -------------
PARAMETERS

    PF_E_Factor 'E-factor to estimate ALT'     /0.045/   
    PF_a11   'Coef.1 from Global to Land'   /1.3721/
    PF_a12   'Coef.2 from Global to Land'   /12.1900/
    PF_a21   'Coef.1 from Land to Permafrost Regions' /1.4330/
    PF_a22   'Coef.2 from Land to Permafrost Regions' /-26.7821/
    PF_a31   'Coef.1 from Permafrost Regions to DDT' /89.4972/
    PF_a32   'Coef.2 from Permafrost Regions to DDT' /1816.7713/
    PF_a41   'Coef.1 from Permafrost Regions to TSummer' /0.3517/
    PF_a42   'Coef.2 from Permafrost Regions to TSummer' /10.9067/
    
    PF_Carbon 'Gt carbon in upper 3m of permafrost regions' /1068/
    PF_CH4_Frac  'Fraction of CH4 in permafrost carbon' /0.023/
    PF_Carbon1 'Gt carbon in upper 1m of permafrost regions' /490.3/
    PF_Carbon2 'Gt carbon in upper 1-2m of permafrost regions' /365.6/
    PF_Carbon3 'Gt carbon in upper 2-3m of permafrost regions' /212.1/
    
    PF_Static_pool 'Static fraction of total thawed permafrost carbon' /0.40/
    PF_Q10         'Q10 parameters' /2.5/
    
;
$endif.perma


##  COMPUTE DATA
#_________________________________________________________________________
$elseif.ph %phase%=='compute_data'

CtoCO2 = 44 / 12 ;
CO2toC = 12 / 44 ;

* Baseline emissions
sigma(t,n) = emi_bau_co2(t,n)/ykali(t,n) ;
sig0(n)    = sigma('1',n)    ;

* Initial emissions
e0(n) = q0(n) * sig0(n);


$if %baseline%=='ssp5' fosslim=10000;

##  DECLARE VARIABLES
#_________________________________________________________________________
$elseif.ph %phase%=='declare_vars'

## EMISSIONS CO2 ----------
VARIABLES

    E(t,n)          'Total CO2 emissions  [GtCO2/year]'
    EIND(t,n)       'Industrial emissions [GtCO2/year]'

    CCAEIND(t)      'Cumulative Industrial Carbon Emissions [GTC]'
    CCAETOT(t)      'Cumulative Carbon Emissions [GTC]'
    CUMETREE(t)     'Cumulative from land [GtC]'

    CCO2EIND(t)     'Cumulative Industrial CO2 Emissions [GtCO2]'
    CCO2ETOT(t)     'Cumulative CO2 Emissions [GtCO2]'

    MIU(t,n)        'Emission control rate GHGs'
    ABATEDEMI(t,n)  'Abated Emissions [GtCO2/year]'
;
POSITIVE VARIABLES  ABATEDEMI, MIU ;

# VARIABLES STARTING LEVELS 
     EIND.l(t,n) = sigma(t,n)*ykali(t,n) ;
        E.l(t,n) = EIND.l(t,n) + eland_bau('uniform',t,n) ;
      MIU.l(t,n) = 0 ; 
ABATEDEMI.l(t,n) = 0 ;

$ifthen.perma %permafrost% == 'pf'
## PERMAFROST -------------
Variables
    PF_C(t)
    PF_DDT(t)
    PF_ALT(t)
    PF_MAAT(t)
    PF_TSUM(t)
    PF_CTOT(t)
    PF_CH4(t)
    PF_CO2(t)
    PF_CTOT2(t)
    PF_CTOT1(t)
    PF_CTOT3(t)
;

POSITIVE VARIABLES  PF_DDT ;

PF_ALT.l(tfirst) = 1.5;

$endif.perma

## EMISSIONS OGHG ----------
$ifthen.oghg %climate% == 'witchoghg'
VARIABLES
    EOGHG(oghg,t,n)       'Total OGHG emissions [GtCO2eq/year]'
    COGHGE(oghg,t)        'Cumulative OGHG emissions [GtCO2eq]'
    MIU_OGHG(oghg,t,n)    'Emission control rate GHGs'
    ABATEDOGHG(oghg,t,n)  'Abated OGHG Emissions [GtCO2eq/year]'
;
POSITIVE VARIABLES  ABATEDOGHG, MIU_OGHG;

# VARIABLES STARTING LEVELS 
     EOGHG.l(oghg,t,n) = oghg_emi_bau(oghg,t,n) ;
ABATEDOGHG.l(oghg,t,n) = 0 ;
  MIU_OGHG.l(oghg,t,n) = 0 ;
$endif.oghg

##  COMPUTE VARIABLES
#_________________________________________________________________________
$elseif.ph %phase%=='compute_vars'

##  EMISSIONS CO2 ----------
* Industrial emissions starting point
EIND.fx(tfirst,n) = e0(n) ;
* Resource limit for fossils emissions
CCAEIND.up(t) = fosslim ;
* Initial cumulated conditions
CCAEIND.FX(tfirst)  = cumeind0    ;
CUMETREE.fx(tfirst) = cumetree0   ;
CCAETOT.FX(tfirst)  = cumeind0 + cumetree0 ;
* CO2-budget starts empty
CCO2EIND.FX(tfirst) = 0 ;
CCO2ETOT.FX(tfirst) = 0 ;

$ifthen.perma %permafrost% == 'pf'
## PERMAFROST -------------
PF_C.fx(tfirst) = 0.9*5;
$endif.perma

##  OGHG EMISSION VARIABLES ----------
$ifthen.oghg %climate% == 'witchoghg'
* Oghg emissions starting point
EOGHG.FX(oghg,tfirst,n)   =  oghg_emi_bau(oghg,tfirst,n);
* OGHG-budget starts empty
COGHGE.FX(oghg,tfirst)    = 0 ;
$endif.oghg

##  CO2 MITIGATION UPPER BOUND SHAPE ----------
loop(t,
# Before transition
MIU.up(t,n)$(t.val lt t_min_miu) = min_miu;
# Transition to negative: linear transition from min_miu to max_miu between t_min_miu and t_max_miu
MIU.up(t,n)$(t.val ge t_min_miu) = min_miu + (max_miu - min_miu) * (t.val - t_min_miu)/(t_max_miu - t_min_miu);
# After transition
MIU.up(t,n)$(t.val gt t_max_miu) = max_miu;
);

##  OGHG MITIGATION UPPER BOUND SHAPE ----------
$ifthen.oghg %climate% == 'witchoghg'
loop(t,
# before transition
MIU_OGHG.up(oghg,t,n)$(t.val lt t_min_miu) = min_miuoghg;
# transition: linear transition from min_miu to max_miu between t_min_miu and t_max_miu
MIU_OGHG.up(oghg,t,n)$(t.val ge t_min_miu) = min_miuoghg + (max_miuoghg - min_miuoghg) * (t.val - t_min_miu)/(t_max_miu - t_min_miu);
# after transition
MIU_OGHG.up(oghg,t,n)$(t.val gt t_max_miu) = max_miuoghg;
);
MIU_OGHG.fx(oghg,tfirst,n) = 0 ; #setting 2015 value
$endif.oghg


#=========================================================================
*   ///////////////////////     OPTIMIZATION    ///////////////////////
#=========================================================================

##  EQUATION LIST
#_________________________________________________________________________
$elseif.ph %phase%=='eql'

##  CO2 EMISSION EQUATIONS ----------
    eq_e                # Emissions equation'
    eq_eind             # Industrial emissions equation'
    eq_ccaeind          # Cumulative carbon emissions equation'
    eq_ccaetot
    eq_cco2eind         # Cumulative CO2 emissions equation (from now on)'
    eq_cco2etot
    eq_cumetree         # Cumulated land-use emissions
    eq_abatedemi        # Abated Emissions according to decision'
#    eq_miuinertiaplus   # Inertia in CO2 Control Rate decreasing'
#    eq_miuinertiaminus  # Inertia in CO2 Control Rate increasing'

$ifthen.perma %permafrost% == 'pf'
## Permafrost Emission Equations --------
    eq_permafrost_carbon # Permafrost emissions'
    eq_permafrost_tair   # permafrost MAAT'
    eq_permafrost_ddt    # permafrost DDT'
    eq_permafrost_alt    # permafrost ALT'
    eq_permafrost_total_carbon # permafrost total carbon emissions'
    eq_permafrost_total_carbon1 # permafrost total carbon emissions 1'
    eq_permafrost_total_carbon2 # permafrost total carbon emissions 2'
    eq_permafrost_total_carbon3 # permafrost total carbon emissions 3'
    eq_permafrost_CO2    # permafrost CO2 emissions'
    eq_permafrost_CH4    # permafrost CH4 emissions'
    eq_permafrost_tsum   # permafrost summer temperature'
$endif.perma

##  OGHG EMISSION EQUATIONS ----------
$ifthen.oghg %climate% == 'witchoghg'
    eq_eoghg                 #'OGHG emissions equation'
    eq_coghge                #'Cumulative OGHG emissions equation'
    eq_abatedoghg            #'Abated OGHG Emissions according to MIU decision'
    eq_oghg_miuinertiaplus   #'Inertia in OGHG Control Rate decreasing'
    eq_oghg_miuinertiaminus  #'Inertia in OGHG Control Rate increasing'
$endif.oghg


##  EQUATIONS
#_________________________________________________________________________
$elseif.ph %phase%=='eqs'

##  EMISSIONS CO2 ----------
* Industrial emissions
 eq_eind(t,n)$(reg(n))..   EIND(t,n)  =E=  sigma(t,n) * YGROSS(t,n) * (1-(MIU(t,n)))  ;

* All emissions
 eq_e(t,n)$(reg(n))..   E(t,n)  =E=  EIND(t,n) + ELAND(t,n);

* Industrial cumulated emissions in Carbon
 eq_ccaeind(t+1)..   CCAEIND(t+1)  =E=  CCAEIND(t) # All industrial emi per period in Carbon
                                   +  (( sum(n$reg(n), EIND(t,n)) + sum(n$(not reg(n)), EIND.l(t,n)) ) * tstep * CO2toC ) ; #Carbon

* Total cumulated emissions in Carbon
 eq_ccaetot(t+1)..   CCAETOT(t+1)  =E=  CCAETOT(t) # All emi (industrial + land) per period in Carbon
$ifthen.perma %permafrost% == 'pf'
                                   + PF_CO2(t)* CO2toC
$endif.perma
                                   +  (( sum(n$reg(n), E(t,n)) + sum(n$(not reg(n)), E.l(t,n)) ) * tstep * CO2toC )  ; #Carbon

* Land Use cumulated emissions in Carbon
 eq_cumetree(t+1)..   CUMETREE(t+1) =E=  CUMETREE(t) # Land Use emi per period in Carbon
                                    + (( sum(n$reg(n), ELAND(t,n))    + sum(n$(not reg(n)), ELAND.l(t,n)) ) * tstep * CO2toC)  ; #Carbon

* Industrial cumulated emissions in CO2
 eq_cco2eind(t+1)..   CCO2EIND(t+1)   =E=  CCO2EIND(t) # All industrial emi per period
                                      +   (( sum(n$reg(n), EIND(t,n))    + sum(n$(not reg(n)), EIND.l(t,n)) )  * tstep )  ; #CO2

* Total cumulated emissions in CO2
 eq_cco2etot(t+1)..   CCO2ETOT(t+1)   =E=  CCO2ETOT(t) # All emi (industrial + land) per period
$ifthen.perma %permafrost% == 'pf'
                                      + PF_CO2(t)
$endif.perma
                                      +   (( sum(n$reg(n), E(t,n))    + sum(n$(not reg(n)), E.l(t,n)) )    * tstep )  ; #CO2

* Emissions abated
 eq_abatedemi(t,n)$(reg(n))..   ABATEDEMI(t,n)  =E=  MIU(t,n) * sigma(t,n) * YGROSS(t,n)  ;

* ++++++++++++++++++++++
$ifthen.perma %permafrost% == 'pf'
 eq_permafrost_carbon(t)$(t.val>1)..   PF_C(t) =e= PF_CTOT(t) - PF_CTOT(t-1);
 eq_permafrost_tair(t)..     PF_MAAT(t) =e= (PF_a11 *TATM(t) + PF_a12) * PF_a21 + PF_a22;
 eq_permafrost_ddt(t)..      PF_DDT(t) =e= PF_MAAT(t) * PF_a31 + PF_a32;
 eq_permafrost_alt(t)..      PF_ALT(t) =e= sqrt(PF_DDT(t)) * PF_E_factor;
 eq_permafrost_tsum(t)..     PF_TSUM(t) =e= PF_MAAT(t) * PF_a41 + PF_a42;
 
 eq_permafrost_total_carbon1(t)$(PF_ALT.l(t)<=1).. PF_CTOT1(t)=e= (PF_ALT(t) * PF_Carbon1);
 eq_permafrost_total_carbon2(t)$((PF_ALT.l(t)>1) and (PF_ALT.l(t)<=2)).. PF_CTOT2(t)=e= (PF_Carbon1 + (PF_ALT(t)-1)*PF_Carbon2);
 eq_permafrost_total_carbon3(t)$((PF_ALT.l(t)>2) and (PF_ALT.l(t)<=3)).. PF_CTOT3(t)=e= (PF_Carbon1 + PF_Carbon2 + (PF_ALT(t)-2)*PF_Carbon3);
 eq_permafrost_total_carbon(t).. PF_CTOT(t)=e= PF_CTOT1(t)$(PF_ALT.l(t)<=1)+PF_CTOT2(t)$((PF_ALT.l(t)>1) and (PF_ALT.l(t)<=2))+PF_CTOT3(t)$((PF_ALT.l(t)>2) and (PF_ALT.l(t)<=3));
 
 eq_permafrost_CH4(t).. PF_CH4(t) =e= 1.333 *    PF_CH4_Frac * (1 - PF_Static_pool) * PF_C(t) * PF_Q10 ** (PF_TSUM(t)/10);   
 eq_permafrost_CO2(t).. PF_CO2(t) =e= 3.666 * (1-PF_CH4_Frac)* (1 - PF_Static_pool) * PF_C(t) * PF_Q10 ** (PF_TSUM(t)/10) + PF_CH4(t)*25;
$endif.perma

##  EMISSIONS OGHG ----------
$ifthen.oghg %climate% == 'witchoghg'
* OGHG emissions
eq_eoghg(oghg,t,n)$(reg(n))..   EOGHG(oghg,t,n)  =E=  oghg_emi_bau(oghg,t,n)  * (1-(MIU_OGHG(oghg,t,n))) ;

* OGHG cumulated emissions in CO2eq
eq_coghge(oghg,t+1)..   COGHGE(oghg,t+1)  =E=  COGHGE(oghg,t) # All oghg-emi per period
                                           + (( sum(n$reg(n), EOGHG(oghg,t,n)) + sum(n$(not reg(n)), EOGHG.l(oghg,t,n)) )* tstep) ; #CO2eq
* OGHG Emissions abated
eq_abatedoghg(oghg,t,n)$(reg(n))..   ABATEDOGHG(oghg,t,n)  =E=  MIU_OGHG(oghg,t,n) * oghg_emi_bau(oghg,t,n) ;
$endif.oghg


##  MITIGATION CO2 INERTIA ----------
* Inertia in increasing
#eq_miuinertiaminus(t+1,n)$(map_nt and (t.val gt 1))..   MIU(t+1,n)  =L=  MIU(t,n) + miu_inertia ;

* Inertia in decreasing
#eq_miuinertiaplus(t+1,n)$(map_nt  and (t.val gt 1))..   MIU(t+1,n)  =G=  MIU(t,n) - miu_inertia ;


##  MITIGATION OGHG INERTIA ----------
$ifthen.oghg %climate% == 'witchoghg'
* Inertia in increasing
eq_oghg_miuinertiaminus(oghg,t,n)$(reg(n)  and (t.val gt 1))..   MIU_OGHG(oghg,t,n)  =L=  MIU_OGHG(oghg,t-1,n) + 0.20  ;

* Inertia in decreasing
eq_oghg_miuinertiaplus(oghg,t,n)$(reg(n)  and (t.val gt 1))..   MIU_OGHG(oghg,t,n)  =G=  MIU_OGHG(oghg,t-1,n) - 0.50  ;
$endif.oghg


##  FIX VARIABLES
#_________________________________________________________________________
$elseif.ph %phase%=='fix_variables'

tfixvar(MIU,'(t,n)')

##  BEFORE SOLVE
#_________________________________________________________________________
$elseif.ph %phase%=='before_solve'

$ontext
loop((t,n)$(ctax(t,n) and (MIU.lo(t,n) lt MIU.up(t,n))),
    MIU.lo(t,n) = max(0, min(1 - (0.90*(YNET.l(t,n)-ABATECOST.l(t,n))/ctax(t,n) + EIND.l(t,n))/(sigma(t,n)*YGROSS.l(t,n)), MIU.up(t,n)));
    MIU.l(t,n) = (MIU.lo(t,n) + MIU.up(t,n))/2;
    EIND.l(t,n) = sigma(t,n)*YGROSS.l(t,n)*(1-MIU.l(t,n));
    ABATEDEMI.l(t,n) = sigma(t,n)*YGROSS.l(t,n)*MIU.l(t,n);
);
$offtext

##  PROBLEMATIC REGIONS
#_________________________________________________________________________
$elseif.ph %phase%=='problematic_regions'


#===============================================================================
*     ///////////////////////     REPORTING     ///////////////////////
#===============================================================================

##  GDX ITEMS
#_________________________________________________________________________
$elseif.ph %phase%=='gdx_items'

# Sets (excl. aliases) ---------------------------------
ghg

# Parameters -------------------------------------------
fosslim
max_miu
t_max_miu
t_min_miu
CtoCO2
CO2toC
sigma
emi_bau_co2

# Variables --------------------------------------------
E
EIND
MIU
ABATEDEMI
CCO2EIND
CCO2ETOT

$ifthen.perma %permafrost% == 'pf'
PF_C
PF_MAAT
PF_DDT
PF_ALT
PF_CTOT
PF_CO2
$endif.perma

# Equations -------------------
eq_e

$endif.ph
