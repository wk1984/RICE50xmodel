* IMPACT BURKE SUB-MODULE
*
* Burke's damage function implemented according to model regional detail
* REFERENCES
* - Burke et al. 2015
#=========================================================================
*   ///////////////////////       SETTING      ///////////////////////
#=========================================================================
##  CONF
#_________________________________________________________________________
$ifthen.ph %phase%=='conf'

* Burke alternatives: | sr | lr | srdiff | lrdiff
$setglobal bhm_spec 'sr'


# OMEGA EQUATION DEFINITION
* | simple | full |
$setglobal  omega_eq 'simple'


## INCLUDE DATA
#_________________________________________________________________________
$elseif.ph %phase%=='include_data'

PARAMETERS
* Short run
    kw_DT          / 0.00641  /
    kw_DT_lag      / 0.00345  /
    kw_TDT         / -.00105  /
    kw_TDT_lag     / -.000718 /
    kw_T           / -.00675  /
;


##  COMPUTE DATA
#_________________________________________________________________________
$elseif.ph %phase%=='compute_data'

## MEDIAN CUTOFF EVALUATION ----------------------------
#...........................................................................
# Not trivial in GAMS,
# ranking code inspired by solution here:
# https://support.gams.com/gams:compute_the_median_of_a_parameter_s_values
#...........................................................................




##  DECLARE VARIABLES
#_________________________________________________________________________
$elseif.ph %phase%=='declare_vars'

VARIABLES
    BIMPACT(t,n)             'Impact coefficient according to Burke equation'
    KOMEGA(t,n)              'Capital-Omega cross factor'
;
KOMEGA.lo(t,n) = 0;


# VARIABLES STARTING LEVELS ----------------------------
BIMPACT.l(t,n) = 0 ;
KOMEGA.l(t,n) = 1 ;

#since requires lags fixed first period
BIMPACT.fx('1',n) = 0 ;

##  COMPUTE VARIABLES
#_________________________________________________________________________
$elseif.ph %phase%=='compute_vars'

##  STABILITY CONSTRAINTS ------------------------------
* to avoid errors/help the solver to converge
BIMPACT.lo(t,n) = (-1 + 1e-6) ; # needed because of eq_omega


#=========================================================================
*   ///////////////////////     OPTIMIZATION    ///////////////////////
#=========================================================================

##  EQUATION LIST
#_________________________________________________________________________
$elseif.ph %phase%=='eql'

eq_bimpact   # BHM yearly impact equation
eq_omega     # Impact over time equation
$if %omega_eq% == 'full' eq_komega     # Capital-Omega impact factor equation (only for full-omega)


##  EQUATIONS
#_________________________________________________________________________
$elseif.ph %phase%=='eqs'

##  BURKE'S IMPACT --------------------------------------
* BHM's yearly local impact
 eq_bimpact(t,n)$(reg(n) and ord(t) gt 1)..  BIMPACT(t,n)  =E=  (kw_DT+kw_DT_lag) * ((TEMP_REGION_DAM(t,n)-TEMP_REGION_DAM(t-1,n))/tlen(t))
                                            +   (kw_TDT+kw_TDT_lag) * ((TEMP_REGION_DAM(t,n)-TEMP_REGION_DAM(t-1,n))/tlen(t)) * TEMP_REGION_DAM(t-1,n)
#                                            -   (kw_DT+kw_DT_lag) * (TEMP_REGION_DAM(t,n)-TEMP_REGION_DAM(t-1,n))
#                                            -   (kw_TDT+kw_TDT_lag) * (TEMP_REGION_DAM(t,n)-TEMP_REGION_DAM(t-1,n)) * TEMP_REGION_DAM(t-1,n)
;

# OMEGA FULL
$ifthen.omg %omega_eq% == 'full'
* Omega full formulation
 eq_omega(t,n)$(reg(n) and not tlast(t))..  OMEGA(t+1,n)  =E=  (  (1 + (OMEGA(t,n)))
                                                                            #  TFP factor
                                                                            *  (tfp(t+1,n)/tfp(t,n))
                                                                            #  Pop factor
                                                                            *  ((( pop(t+1,n)/1000  )/( pop(t,n)/1000 ))**(1-gama)) * (pop(t,n)/pop(t+1,n))
                                                                            #  Capital-Omega factor
                                                                            *  KOMEGA(t,n)
                                                                            #  BHM impact on pc-growth
                                                                            /  ((1 + basegrowthcap(t,n) +  BIMPACT(t,n)   )**tstep)
                                                                        ) - 1  ;

* Capital-Omega factor
 eq_komega(t,n)$(reg(n))..  KOMEGA(t,n)  =E=  ( (((1-dk)**tstep) * K(t,n)  +  tstep * S(t,n) * tfp(t,n) * (K(t,n)**gama) * ((pop(t,n)/1000)**(1-gama)) * (1/(1+OMEGA(t,n))) ) / K(t,n) )**gama  ;
# OMEGA SIMPLE
$else.omg
* Omega-simple formulation
 eq_omega(t,n)$(reg(n)  and not tlast(t))..  OMEGA(t+1,n)  =E=  (  (1 + (OMEGA(t,n))) / ((1 + BIMPACT(t,n))**tstep)  ) - 1  ;
$endif.omg


#===============================================================================
*     ///////////////////////     REPORTING     ///////////////////////
#===============================================================================

##  REPORT
#_________________________________________________________________________
$elseif.ph %phase%=='report'


##  GDX ITEMS
#_________________________________________________________________________
$elseif.ph %phase%=='gdx_items'

# Variables --------------------------------------------
BIMPACT
KOMEGA


$endif.ph
