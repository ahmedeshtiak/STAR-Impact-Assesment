/*******************************************************************************
Project:		YRF 
Organization:	BIGD, BracU
Author:			Ahmed Eshtiak
Date created:	12/03/2026
Last edited:	12/03/2026
Last edited by: Ahmed Eshtiak
Description:	Final EXAM; YRF Evaluation
				
	
*******************************************************************************/

********************
**# Necessary Setup
********************
clear all                     
clear matrix                
set more off                  
version 17                   
cap log close _all          
cap estimates drop _all   
set maxvar 50000

**# Directory Setup
global ROOT  "D:\Ahmed Eshtiak\Local Disk E\Projects\STAR+ Impact Assesment"

global RAW    "${ROOT}/0_raw"
global CLEAN  "${ROOT}/1_clean"
global DO     "${ROOT}/3_do"
global RESULT "${ROOT}/4_result"
global GRAPH  "${ROOT}/5_graph"


* names of the raw files (without extension)
global BL_RAW "${RAW}/STAR+ Baseline"
global EL_RAW "${RAW}/STAR+ Endline"

* ---- friendly path check: stop early with a clear message if data not found  *
capture confirm file "${BL_RAW}.dta"
if _rc {
    display as error "Baseline not found at: ${BL_RAW}.dta"
    display as error "Fix the global ROOT above, and make sure both raw .dta files"
    display as error "sit inside a sub-folder named  0_raw."
    exit 601
}


********************************************************************************
**# A.  BUILD A CLEAN BASELINE ANALYSIS FILE  (constructed once, reused)
********************************************************************************
use "${RAW}/STAR+ Baseline", clear
gen division = ""
replace division = "Barishal"   if inlist(s1q5,"Barisal","Bhola","Patuakhali")
replace division = "Chattogram" if inlist(s1q5,"Chittagong","Chandpur","Comilla","Brahmanbaria","Lakshmipur","Noakhali","Feni")
replace division = "Dhaka"      if inlist(s1q5,"Dhaka","Gazipur","Gopalganj","Kishorgonj","Madaripur","Manikganj","Munshiganj")
replace division = "Dhaka"      if inlist(s1q5,"Narayanganj","Narsingdi","Rajbari","Shariatpur","Tangail")
replace division = "Khulna"     if inlist(s1q5,"Chuadanga","Jessore","Khulna","Kushtia","Satkhira")
replace division = "Mymensingh" if inlist(s1q5,"Jamalpur","Mymensingh","Sherpur")
replace division = "Rajshahi"   if inlist(s1q5,"Bogra","Nawabganj","Pabna","Rajshahi","Sirajganj")
replace division = "Rangpur"    if inlist(s1q5,"Dinajpur","Lalmonirhat","Panchagarh","Rangpur")
assert division != ""                       // all 39 districts must map
encode division, gen(division_code)
label var division_code "Division (stratification level)"

encode branch, gen(branch_code)
label var branch_code "Branch (randomisation level)"


* --- balance / control covariates ------------------------------------------- *
gen youth_age = res_age
label var youth_age "Youth age (years)"

gen  youth_male = (res_gender=="Male") if !missing(res_gender)
label var youth_male "Youth is male (1=yes)"

gen youth_married = (res_marital_code==2) if !missing(res_marital_code)   // [Q3e] keep missing as missing
label var youth_married "Youth is married (1=yes)"

gen hh_size = tot_mem
label var hh_size "Household size"

gen land_amount = q411
label var land_amount "Land amount (decimal)"

gen num_cows = q4131
label var num_cows "Number of cows"

gen num_goats_sheep = q4141
label var num_goats_sheep "Goats / sheep owned"

egen youth_income_bl = rowtotal(q11col12_1 q11col12_2 q11col12_3 q11col12_4) // q11 recodrds the employment of youth
replace youth_income_bl = 0 if q911 ==0 
label var youth_income_bl "Youth monthly income - baseline (BDT)"
egen other_earn = rowtotal(q15col9_*_*) // q15 recodrds the employment of other member
gen monthly_hh_income = youth_income_bl + other_earn
label var monthly_hh_income "Household monthly income (BDT)"

global BALVARS "youth_age youth_male youth_married hh_size land_amount num_cows num_goats_sheep monthly_hh_income"
mdesc

keep idno treatment division division_code branch_code  $BALVARS youth_income_bl
mdesc 
drop if hh_size ==.
label data "STAR+ baseline - cleaned analysis file"
save "${CLEAN}/baseline_clean.dta", replace

********************************************************************************
**# B.  BUILD A CLEAN ENDLINE ANALYSIS FILE  (constructed once, reused)
********************************************************************************
use "${RAW}/STAR+ Endline", clear

* consent
gen has_consent = (trim(learner_c) != "") | (trim(guardian_c) != "")
drop if has_consent==0

* --- slot 1 ---
gen wage_inc_1        = q11col12_1    if q11col4_1 == 2
gen self_year_gross_1 = newq11col13_1 if q11col4_1 == 1
gen self_year_exp_1   = newq11col14_1 if q11col4_1 == 1
gen double self_gross_1 = self_year_gross_1 / 12
gen double self_exp_1   = self_year_exp_1   / 12
recode wage_inc_1 self_gross_1 self_exp_1 (.=0)


* --- slot 2 ---
gen wage_inc_2        = q11col12_2    if q11col4_2 == 2
gen self_year_gross_2 = newq11col13_2 if q11col4_2 == 1
gen self_year_exp_2   = newq11col14_2 if q11col4_2 == 1
gen double self_gross_2 = self_year_gross_2 / 12
gen double self_exp_2   = self_year_exp_2   / 12
recode wage_inc_2 self_gross_2 self_exp_2 (.=0)


* --- slot 3 ---
gen wage_inc_3        = q11col12_3    if q11col4_3 == 2
gen self_year_gross_3 = newq11col13_3 if q11col4_3 == 1
gen self_year_exp_3   = newq11col14_3 if q11col4_3 == 1
gen  self_gross_3 = self_year_gross_3 / 12
gen double self_exp_3   = self_year_exp_3   / 12
recode wage_inc_3 self_gross_3 self_exp_3 (.=0)

* --- combine ---
gen youth_income = (wage_inc_1   + wage_inc_2   + wage_inc_3)   + (self_gross_1 + self_gross_2 + self_gross_3)  - (self_exp_1   + self_exp_2   + self_exp_3)
replace youth_income = 0 if q911 == 0

label var youth_income "Youth monthly income - endline (BDT)"


gen  employed = q911
label define employed 0 "Unemployed" 1 "Employed"
label values employed employed
label var employed "Youth Employement"


//keep idno participant youth_income employed
label data "STAR+ endline - cleaned analysis file"
save "${CLEAN}/endline_clean.dta", replace


********************************************************************************
**# Q1.  DEMOGRAPHIC MODULE - LONG DATASET
********************************************************************************
use "${RAW}/STAR+ Baseline", clear

keep idno lino_* col2_* col4_* col6y_* col7_*
drop lino_loan_*

reshape long lino_ col2_ col4_ col6y_ col7_, i(idno) j(memlino)
drop if missing(col4_)

// rename (idno lino_ col2_ col4_ col6y_ col7_) (final_id member_id name sex age marital_status)
rename idno         final_id
rename lino_        member_id
rename col2_        name
rename col4_        sex
rename col6y_       age
rename col7_        marital_status

destring member_id, replace
order final_id member_id name sex age marital_status

label define sex 1 "Male" 2 "Female" 3 "Transgender", replace
label values sex sex
label define marital 1 "Unmarried" 2 "Married" 3 "Divorced" 4 "Widow" 5 "Separated", replace
label values marital_status marital

label var final_id       "Final ID (Household / Youth ID)"
label var member_id      "Member ID (line number)"
label var name           "Name"
label var sex            "Sex"
label var age            "Age (years)"
label var marital_status "Marital status"

order final_id member_id name sex age marital_status
sort  final_id member_id
label data "STAR+ baseline - demographic module (long)"
save "${CLEAN}/demographic_long.dta", replace


********************************************************************************
**# Q2.  DISABILITY DISTRIBUTION - BAR GRAPH (treatment vs control)
********************************************************************************
use "${RAW}/STAR+ Baseline", clear

collapse (sum) res_disability_1 res_disability_2 res_disability_3 res_disability_4 res_disability_5 res_disability_6 res_disability_7 res_disability_8 res_disability_9 res_disability_10 res_disability_11 res_disability_555, by(treatment)

rename res_disability_1   dis1
rename res_disability_2   dis2
rename res_disability_3   dis3
rename res_disability_4   dis4
rename res_disability_5   dis5
rename res_disability_6   dis6
rename res_disability_7   dis7
rename res_disability_8   dis8
rename res_disability_9   dis9
rename res_disability_10  dis10
rename res_disability_11  dis11
rename res_disability_555 dis12

reshape long dis, i(treatment) j(disability_type)

label define disability_type 1 "Autism" 2 "Physical" 3 "Mental Health" 4 "Eyesight" 5 "Speech" 6 "Hearing" 7 "Intelligence" 8 "Hearing & Eyesight" 9 "Cerebral Palsy" 10 "Down Syndrome" 11 "Multiple" 12 "Others"
label values disability_type disability_type

rename dis count
reshape wide count, i(disability_type) j(treatment)
rename count0 control
rename count1 treatment
gen total = control + treatment

* within-arm shares (a youth can report >1 disability => not mutually exclusive)
egen total_control   = total(control)
egen total_treatment = total(treatment)
gen control_pct   = 100*control   / total_control
gen treatment_pct = 100*treatment / total_treatment

gen common = (total >= 30)      // split common vs rare for readability

graph hbar control_pct treatment_pct if common==1,                          ///
    over(disability_type, sort(total) descending label(labsize(small)))     ///
    bar(1, color("33 102 172") lcolor(white) lwidth(vthin))                 ///
    bar(2, color("178 24 43")  lcolor(white) lwidth(vthin))                 ///
    legend(label(1 "Control") label(2 "Treatment")                          ///
           position(6) rows(1) size(small) region(lcolor(gs12)))            ///
    title("{bf:A.} Common disability types", size(medsmall)                 ///
          color(black) position(11))                                        ///
    ytitle("% of group total", size(small))                                 ///
    blabel(bar, size(vsmall) format(%4.1f) suffix("%") position(outside))   ///
    ylabel(0(5)30, labsize(small) grid glcolor(gs14) glpattern(dash))       ///
    graphregion(color(white)) plotregion(color(white))                      ///
    name(panel_common, replace) nodraw

graph hbar control_pct treatment_pct if common==0,                          ///
    over(disability_type, sort(total) descending label(labsize(small)))     ///
    bar(1, color("33 102 172") lcolor(white) lwidth(vthin))                 ///
    bar(2, color("178 24 43")  lcolor(white) lwidth(vthin))                 ///
    legend(off)                                                             ///
    title("{bf:B.} Rare disability types", size(medsmall)                   ///
          color(black) position(11))                                        ///
    ytitle("% of group total", size(small))                                 ///
    blabel(bar, size(vsmall) format(%4.1f) suffix("%") position(outside))   ///
    ylabel(0(0.5)2, labsize(small) grid glcolor(gs14) glpattern(dash))      ///
    graphregion(color(white)) plotregion(color(white))                      ///
    name(panel_rare, replace) nodraw

graph combine panel_common panel_rare,                                      ///
    rows(1) imargin(small)                                                  ///
    title("Distribution of disability types by treatment and control",      ///
          size(medium) color(black))                                        ///
    subtitle("STAR+ baseline", size(small) color(gs6))                      ///
    note("Within-arm shares of total reported disabilities;"                ///
         "categories are not mutually exclusive.",                          ///
         size(vsmall) color(gs8))                                           ///
    graphregion(color(white)) name(disability_dist, replace)

graph export "${GRAPH}/disability_distribution.png", width(3000) height(1500) replace


********************************************************************************
**# Q3.  BALANCE TABLE  (treatment vs control)
********************************************************************************
use "${CLEAN}/baseline_clean.dta", clear

iebaltab youth_age youth_male youth_married hh_size land_amount num_cows num_goats_sheep monthly_hh_income, grpvar(treatment) fixedeffect(division_code) vce(cluster branch_code) ftest rowvarlabels stats(desc(sd)) savexlsx("${RESULT}/balance_table.xlsx") replace

********************************************************************************
**# Q4.  ATTRITION TEST
********************************************************************************
use "${CLEAN}/baseline_clean.dta", clear
                  
* attrition = surveyed at baseline but NOT re-interviewed at endline
merge 1:1 idno using "${CLEAN}/endline_clean.dta"
gen attrited = 0
replace attrited = 1 if _merge == 1
drop if _merge==2                    
drop _merge

* attrition 1 - simple
reg attrited treatment
outreg2 using "${RESULT}/attrition.xls", replace excel label

* attrition 2 - with controls
reg attrited treatment youth_age i.youth_male i.youth_married hh_size land_amount num_cows num_goats_sheep monthly_hh_income i.division_code, vce(cluster branch_code)
outreg2 using "${RESULT}/attrition.xls", append excel label 

* attrition 3 - with interactions
regress attrited i.treatment youth_age i.youth_male i.youth_married hh_size land_amount num_cows num_goats_sheep monthly_hh_income i.division_code i.treatment#c.youth_age i.treatment#i.youth_male i.treatment#i.youth_married i.treatment#c.hh_size i.treatment#c.land_amount i.treatment#c.num_cows i.treatment#c.num_goats_sheep i.treatment#c.monthly_hh_income, vce(cluster branch_code)
outreg2 using "${RESULT}/attrition.xls", append excel 

********************************************************************************
**# Q5.  ITT and LATE  (income & employment)
********************************************************************************
use "${CLEAN}/endline_clean.dta", clear
merge 1:1 idno using "${CLEAN}/baseline_clean.dta"
keep if _merge==3
drop _merge

sum youth_income employed treatment participant


// income ITT
regress youth_income treatment i.division_code, vce(cluster branch_code)
outreg2 using "${RESULT}/itt_late_results.xls", replace  ctitle("ITT - Income") addtext(Division FE, Yes) label

// employment ITT 
regress employed treatment i.division_code, vce(cluster branch_code)
outreg2 using "${RESULT}/itt_late_results.xls", append  ctitle("ITT - Employed") addtext(Division FE, Yes) label

// LATE - income
ivregress 2sls youth_income i.division_code (participant = treatment),vce(cluster branch_code) 
outreg2 using "${RESULT}/itt_late_results.xls", append  ctitle("LATE - Income ") addtext(Division FE, Yes) label

* LATE - employment
ivregress 2sls employed i.division_code (participant = treatment), vce(cluster branch_code) 
outreg2 using "${RESULT}/itt_late_results.xls", append keep(participant) ctitle("LATE - Employed") addtext(Division FE, Yes) label


********************************************************************************
**# Q6.  ITT / LATE WITH BASELINE COVARIATES
********************************************************************************
use "${CLEAN}/endline_clean.dta", clear
merge 1:1 idno using "${CLEAN}/baseline_clean.dta"
keep if _merge==3
drop _merge

local base youth_age youth_male youth_married hh_size land_amount num_cows num_goats_sheep monthly_hh_income

// ITT - Income + baseline
regress youth_income treatment youth_age youth_male youth_married hh_size land_amount num_cows num_goats_sheep monthly_hh_income i.division_code, vce(cluster branch_code)
outreg2 using "${RESULT}/itt_late_results.xls", append  ctitle("ITT - Income With Basline") addtext(Division FE, Yes, Baseline Control, Yes) label

// ITT - Employed + baseline
regress employed treatment youth_age youth_male youth_married hh_size land_amount num_cows num_goats_sheep monthly_hh_income i.division_code, vce(cluster branch_code)
outreg2 using "${RESULT}/itt_late_results.xls", append  ctitle("ITT - Employement With Basline") addtext(Division FE, Yes, Baseline Control, Yes) label

* LATE + covariates
ivregress 2sls youth_income (participant = treatment) youth_age youth_male youth_married hh_size land_amount num_cows num_goats_sheep monthly_hh_income i.division_code, vce(cluster branch_code)
outreg2 using "${RESULT}/itt_late_results.xls", append  ctitle("LATE - Income With Basline") addtext(Division FE, Yes, Baseline Control, Yes) label

ivregress 2sls employed (participant = treatment)  youth_age youth_male youth_married hh_size land_amount num_cows num_goats_sheep monthly_hh_income i.division_code, vce(cluster branch_code)
outreg2 using "${RESULT}/itt_late_results.xls", append  ctitle("LATE - Employemnt With Basline") addtext(Division FE, Yes, Baseline Control, Yes) label

********************************************************************************
**# Q7.  HETEROGENEITY BY GENDER  (controlling for baseline covariates)
********************************************************************************
use "${CLEAN}/endline_clean.dta", clear
merge 1:1 idno using "${CLEAN}/baseline_clean.dta"
keep if _merge==3
drop _merge

// interaction term
gen male_int = treatment*youth_male
gen parti_male = participant * youth_male

* ITT heterogeneity: income  (treatment x male)
regress youth_income treatment youth_male male_int youth_age youth_married hh_size land_amount num_cows num_goats_sheep monthly_hh_income i.division_code, vce(cluster branch_code)

outreg2 using "${RESULT}/itt_late_results.xls", append ctitle("ITT Gender Heterogenety- Income") addtext(Division FE, Yes, Baseline covariates, Yes) label

* ITT heterogeneity: employemnt income  (treatment x male)
regress employed treatment youth_male male_int youth_age youth_married hh_size land_amount num_cows num_goats_sheep monthly_hh_income i.division_code, vce(cluster branch_code)

outreg2 using "${RESULT}/itt_late_results.xls", append ctitle("ITT Gender Heterogenety- Employment") addtext(Division FE, Yes, Baseline covariates, Yes) label

* LATE heterogeneity: income  (treatment x male)
ivregress 2sls youth_income (participant = treatment) youth_age youth_male youth_married hh_size land_amount num_cows num_goats_sheep monthly_hh_income i.division_code, vce(cluster branch_code)

outreg2 using "${RESULT}/itt_late_results.xls", append  ctitle("LATE Gender Heterogenety - Income") addtext(Division FE, Yes, Baseline covariates, Yes) label

* LATE heterogeneity: employemnt  (treatment x male)
ivregress 2sls employed youth_male youth_age youth_married hh_size land_amount num_cows num_goats_sheep monthly_hh_income i.division_code (participant parti_male = treatment male_int), vce(cluster branch_code)

outreg2 using "${RESULT}/itt_late_results.xls", append ctitle("LATE Gender Heterogenety - Employment") addtext(Division FE, Yes, Baseline covariates, Yes) label


********************************************************************************
**# Q8  DiD  and  FIXED-EFFECTS
********************************************************************************
// baseline
use "${CLEAN}/baseline_clean.dta", clear
rename youth_income_bl youth_income
gen time = 0
tempfile bl_panel
save `bl_panel'

// Endline
use "${CLEAN}/endline_clean.dta", clear
gen time = 1
tempfile el_panel
save `el_panel'

// append
use `bl_panel', clear
append using `el_panel'

// balance pannel
sort idno time
duplicates tag idno, gen(dup)
keep if dup > 0
drop dup
isid idno time
xtset idno time

// time treatment interaction
gen treat_post = treatment * time
label var treat_post "Treatment x Post"

//DiD
regress youth_income treatment time treat_post i.division_code, vce(cluster branch_code)
outreg2 using "${RESULT}/did_fe_results.xls", replace ctitle("DiD - Income") addtext(Division FE, Yes, Individual FE, No) label

//Fixed Effect
xtreg youth_income time treat_post i.division_code, fe vce(cluster branch_code)
outreg2 using "${RESULT}/did_fe_results.xls", append ctitle("FE - Income") addtext(Division FE, n/a, Individual FE, Yes) label
