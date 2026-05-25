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

clear all                     
clear matrix                
set more off                  
version 17                   
cap log close _all          
cap estimates drop _all   
set maxvar 50000

********************
**# Install Packages

///ssc install fre, replace
///ssc install mdesc, replace
//ssc install conindex, replace
//ssc install glcurve, replace
//ssc install oaxaca, replace
//ssc install labutil

*******************
**#Directory setup

global EXAM "C:\Users\User\Desktop\EXAM"

* Set global paths
global RAW "${EXAM}\0_raw"
global CLEAN "${EXAM}\1_clean"
global DO "${EXAM}\3_do"
global RESULT "${EXAM}\4_result"
global GRAPH "${EXAM}\5_graph"

**********************************
**#Q1 demographic module
use "${RAW}\STAR+ Baseline", clear

keep idno lino_* col2_* col4_* col6y_* col7_*
drop lino_loan_1 lino_loan_2 lino_loan_3 lino_loan_4 lino_loan_5 lino_loan_6 lino_loan_7 lino_loan_8 lino_loan_9 lino_loan_10

*raname 
forvalues i = 1/17 {
    rename lino_`i'  member_id`i'
    rename col2_`i'  name`i'
    rename col4_`i'  sex`i'
    rename col6y_`i' age`i'
    rename col7_`i'  marital_status`i'
}

reshape long member_id name sex age marital_status, i(idno) j(memlino)


drop if sex ==.

rename idno final_id
destring member_id, replace

order final_id member_id name sex age marital_status

label variable final_id        "Final ID (Household/Youth ID)"
label variable member_id       "Member ID (Line Number)"
label variable name            "Name"
label variable sex             "Sex"
label variable age             "Age (Years)"
label variable marital_status  "Marital Status"

save "${CLEAN}\STAR+ Baseline", replace


**********************************
**#Q2 disablity graph
use "${RAW}\STAR+ Baseline", clear

collapse (sum) res_disability_1 res_disability_2 res_disability_3  res_disability_4 res_disability_5 res_disability_6  res_disability_7 res_disability_8 res_disability_9  res_disability_10 res_disability_11 res_disability_555,  by(treat)

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

reshape long dis, i(treat) j(disability_type)

label define disability_type ///
    1 "Autism" 2 "Physical" 3 "Mental Health" 4 "Eyesight"  ///
    5 "Speech" 6 "Hearing" 7 "Intelligence"                 ///
    8 "Hearing & Eyesight" 9 "Cerebral Palsy"               ///
    10 "Down Syndrome" 11 "Multiple" 12 "Others"
label values disability_type disability_type

rename dis count
reshape wide count, i(disability_type) j(treat)
rename count0 control
rename count1 treatment
gen total = control + treatment

* Calculate group totals for percentage denominator
egen total_control   = total(control)
egen total_treatment = total(treatment)

* Convert to percentages
gen control_pct   = (control   / total_control)   * 100
gen treatment_pct = (treatment / total_treatment) * 100

* Common (total >= 30) vs rare
gen byte common = (total >= 30)

* Common disabilities
graph hbar control_pct treatment_pct if common == 1,               ///
    over(disability_type, sort(total) descending label(labsize(small))) ///
    bar(1, color("33 102 172") lcolor(white) lwidth(vthin))         ///
    bar(2, color("178 24 43")  lcolor(white) lwidth(vthin))         ///
    legend(label(1 "Control") label(2 "Treatment")                  ///
           position(6) rows(1) size(small) region(lcolor(gs12)))    ///
    title("{bf:A.} Common Disability Types", size(medsmall)         ///
          color(black) position(11))                                ///
    ytitle("% of Group Total", size(small))                         ///
    blabel(bar, size(vsmall) format(%4.1f) suffix("%") position(outside)) ///
    ylabel(0(5)30, labsize(small) grid glcolor(gs14)                ///
           glpattern(dash))                                         ///
    graphregion(color(white)) plotregion(color(white))              ///
    scheme(s2color)                                                 ///
    name(panel_common, replace) nodraw

* Rare disabilities
graph hbar control_pct treatment_pct if common == 0,               ///
    over(disability_type, sort(total) descending label(labsize(small))) ///
    bar(1, color("33 102 172") lcolor(white) lwidth(vthin))         ///
    bar(2, color("178 24 43")  lcolor(white) lwidth(vthin))         ///
    legend(off)                                                     ///
    title("{bf:B.} Rare Disability Types", size(medsmall)           ///
          color(black) position(11))                                ///
    ytitle("% of Group Total", size(small))                         ///
    blabel(bar, size(vsmall) format(%4.1f) suffix("%") position(outside)) ///
    ylabel(0(0.5)2, labsize(small) grid glcolor(gs14)               ///
           glpattern(dash))                                         ///
    graphregion(color(white)) plotregion(color(white))              ///
    scheme(s2color)                                                 ///
    name(panel_rare, replace) nodraw

* Combine
graph combine panel_common panel_rare,                              ///
    rows(1) imargin(small)                                          ///
    title("Distribution of Disability Types"                        ///
          "by Treatment and Control Groups",                        ///
          size(medium) color(black))                                ///
    subtitle("STAR+ Baseline", size(small) color(gs6))              ///
    note("Note: Percentages are within-group shares of total reported disabilities." ///
         "Categories are not mutually exclusive.",                  ///
         size(vsmall) color(gs8))                                   ///
    graphregion(color(white))                                       ///
    name(disability_dist, replace)

graph export "${GRAPH}\disability_distribution.png", width(3000) height(1500) replace
	

**********************************
**#Q3 balance table
use "${RAW}\STAR+ Baseline", clear


encode branch, gen(branch_id)

// OUTCOME VARIABLES FOR BALANCE TEST

fre res_age res_gender res_marital_code tot_mem 

// q411 - land co
//q4131 - cow
// q4141 - goat
// q11col12_4 q11col12_3 q11col12_2 q11col12_1 - earning


// 1. Youth Age
gen youth_age = res_age
label var youth_age "Youth Age (years)"


// 2. Youth Male (binary)
gen youth_male = (res_gender == "Male")
label var youth_male "Youth is Male"

// 3. Youth Married (binary)  
gen youth_married = (res_marital_code == 2)
label var youth_married "Youth is Married"

// 4. Household Size
gen hh_size = tot_mem
label var hh_size "Household Size"

// 5. Land Amount
gen land_amount = q411
label var land_amount "Land Amount"

// 6. Number of Cows
gen num_cows = q4131
label var num_cows "Number of Cows"

// 7. Number of Goats/Sheep
gen num_goats_sheep = q4141
label var num_goats_sheep "Goats/Sheep Owned"

// 8. Monthly Income (sum of sources)
foreach i of numlist 1/4 {
    capture confirm variable q11col12_`i'
    if !_rc {
        replace q11col12_`i' = 0 if missing(q11col12_`i')
    }
}
egen youth_earn = rowtotal(q11col12_1 q11col12_2 q11col12_3 q11col12_4)

* Other household members  earning
foreach m of numlist 1/11 {
    foreach a of numlist 1/3 {
        capture confirm variable q15col9_`m'_`a'
        if !_rc {
            replace q15col9_`m'_`a' = 0 if missing(q15col9_`m'_`a')
        }
    }
}
egen other_earn = rowtotal(q15col9_*_*)

gen monthly_income = youth_earn + other_earn
label variable monthly_income "Household monthly average income (BDT)"



bysort treatment: summarize youth_age youth_male youth_married hh_size land_amount num_cows num_goats_sheep monthly_income, d


eststo clear


preserve
drop if youth_age ==.
reg youth_age i.treat, cluster(branch_id)
eststo b1
restore

preserve
drop if youth_male ==.
reg youth_male i.treat, cluster(branch_id)
eststo b2
restore

preserve
drop if youth_married==.
reg youth_married i.treat, cluster(branch_id)
eststo b3
restore

preserve
drop if hh_size==.
reg hh_size i.treat, cluster(branch_id)
eststo b4
restore 

preserve
drop if land_amount==.
reg land_amount i.treat, cluster(branch_id)
eststo b5
restore

preserve
drop if num_cows==.
reg num_cows i.treat, cluster(branch_id)
eststo b6
restore
reg num_goats_sheep i.treat, cluster(branch_id)
eststo b7

preserve
drop if monthly_income==.
reg monthly_income i.treat, cluster(branch_id)
eststo b8
restore 


esttab b1 b2 b3 b4 b5 b6 b7 b8, ///
    cells(b(fmt(a3) star) se(par fmt(a3))) ///
    wide label ///
    note("clustered at branch")


label var youth_age "Youth Age (years)"
label var youth_male "Youth is Male (1=Yes)"
label var youth_married "Youth is Married (1=Yes)"
label var hh_size "Household Size"
label var land_amount "Land Amount (units)"
label var num_cows "Number of Cows"
label var num_goats_sheep "Goats/Sheep Owned"
label var monthly_income "Monthly Income (BDT)"

esttab b1 b2 b3 b4 b5 b6 b7 b8 ///
    using "$RESULT\balance_table.rtf", ///
    replace ///
    cells(b(fmt(a3) star) se(par fmt(a3))) ///
    wide label
	
	
**********************************
**#Q4 attrition test
use "${RAW}\STAR+ Baseline", clear


encode branch, gen(branch_id)
drop if col2_1 == "" | col2_1 == " " | missing(col2_1)

* Merge with endline to identify attrited observations
merge 1:1 idno using "${RAW}\STAR+ Endline", keepusing(idno)

* Attrited = in baseline but NOT in endline
gen attrited = (_merge == 1)
label variable attrited "Attrited (1 = not found in endline)"
label define attrited 0 "Retained" 1 "Attrited"
label values attrited attrited

* Drop endline-only observations (not relevant for baseline attrition analysis)
drop if _merge == 2
drop _merge

* Tabulate attrition by treatment group
tab attrited treatment, row chi2


// 1. Youth Age
gen youth_age = res_age
label var youth_age "Youth Age (years)"


// 2. Youth Male (binary)
gen youth_male = (res_gender == "Male")
label var youth_male "Youth is Male"

// 3. Youth Married (binary)  
gen youth_married = (res_marital_code == 2)
label var youth_married "Youth is Married"

// 4. Household Size
gen hh_size = tot_mem
label var hh_size "Household Size"

// 5. Land Amount
gen land_amount = q411
label var land_amount "Land Amount"


// 6. Number of Cows
gen num_cows = q4131
label var num_cows "Number of Cows"

// 7. Number of Goats/Sheep
gen num_goats_sheep = q4141
label var num_goats_sheep "Goats/Sheep Owned"

* Youth's earnings (sum across up to 4 earning activities)
foreach i of numlist 1/4 {
    capture confirm variable q11col12_`i'
    if !_rc {
        replace q11col12_`i' = 0 if missing(q11col12_`i')
    }
}
egen youth_earn = rowtotal(q11col12_1 q11col12_2 q11col12_3 q11col12_4)

* Other household members  earning
foreach m of numlist 1/11 {
    foreach a of numlist 1/3 {
        capture confirm variable q15col9_`m'_`a'
        if !_rc {
            replace q15col9_`m'_`a' = 0 if missing(q15col9_`m'_`a')
        }
    }
}
egen other_earn = rowtotal(q15col9_*_*)

gen monthly_income = youth_earn + other_earn
label variable monthly_income "Household monthly average income (BDT)"



gen division = ""

* Barishal Division
replace division = "Barishal" if inlist(s1q5, "Barisal", "Bhola", "Patuakhali")

* Chattogram Division
replace division = "Chattogram" if inlist(s1q5, "Chittagong", "Chandpur", "Comilla",  "Brahmanbaria", "Lakshmipur", "Noakhali", "Feni")

* Dhaka Division
replace division = "Dhaka" if inlist(s1q5, "Dhaka", "Gazipur", "Gopalganj", "Kishorgonj", "Madaripur", "Manikganj", "Munshiganj")
replace division = "Dhaka" if inlist(s1q5, "Narayanganj", "Narsingdi", "Rajbari",  "Shariatpur", "Tangail")

* Khulna Division
replace division = "Khulna" if inlist(s1q5, "Chuadanga", "Jessore", "Khulna",  "Kushtia", "Satkhira")

* Mymensingh Division
replace division = "Mymensingh" if inlist(s1q5, "Jamalpur", "Mymensingh", "Sherpur")

* Rajshahi Division
replace division = "Rajshahi" if inlist(s1q5, "Bogra", "Nawabganj", "Pabna", "Rajshahi", "Sirajganj")

* Rangpur Division
replace division = "Rangpur" if inlist(s1q5, "Dinajpur", "Lalmonirhat",  "Panchagarh", "Rangpur")

* Verify no missing divisions
tab division, missing


* Encode division for regression
encode division, gen(division_code)
label variable division_code "Division (stratification level)"



* 1. Generate interaction terms manually

gen treat_X_youth_age = treatment * youth_age
label variable treat_X_youth_age "Treatment × youth_age"

gen treat_X_youth_male = treatment * youth_male
label variable treat_X_youth_male "Treatment × youth_male"

gen treat_X_youth_married = treatment * youth_married
label variable treat_X_youth_married "Treatment × youth_married"

gen treat_X_hh_size = treatment * hh_size
label variable treat_X_hh_size "Treatment × hh_size"

gen treat_X_land_amount = treatment * land_amount
label variable treat_X_land_amount "Treatment × land_amount"

gen treat_X_num_cows = treatment * num_cows
label variable treat_X_num_cows "Treatment × num_cows"

gen treat_X_num_goats_sheep = treatment * num_goats_sheep
label variable treat_X_num_goats_sheep "Treatment × num_goats_sheep"

gen treat_X_monthly_income = treatment * monthly_income
label variable treat_X_monthly_income "Treatment × monthly_income"

* 2. Run the regression to test attrition
reg attrited i.treatment youth_age i.youth_male i.youth_married hh_size land_amount num_cows num_goats_sheep monthly_income treat_X_youth_age treat_X_youth_male treat_X_youth_married treat_X_hh_size treat_X_land_amount treat_X_num_cows treat_X_num_goats_sheep treat_X_monthly_income i.division_code, cluster(branch_id)


outreg2 using "${RESULT}\attrition.xls", excel replace label dec(3) addstat("Adj. R-squared", e(r2_a), "F-statistic", e(F))


**********************************
**#Q5 ITT and LATE

use "${RAW}\STAR+ Baseline", clear
drop if col2_1 == "" | col2_1 == " " | missing(col2_1)

encode branch, gen(branch_code)

gen division = ""
replace division = "Barishal" if inlist(s1q5, "Barisal", "Bhola", "Patuakhali")
replace division = "Chattogram" if inlist(s1q5, "Chittagong", "Chandpur", "Comilla", "Brahmanbaria", "Lakshmipur", "Noakhali", "Feni")
replace division = "Dhaka" if inlist(s1q5, "Dhaka", "Gazipur", "Gopalganj", "Kishorgonj", "Madaripur", "Manikganj", "Munshiganj")
replace division = "Dhaka" if inlist(s1q5, "Narayanganj", "Narsingdi", "Rajbari", "Shariatpur", "Tangail")
replace division = "Khulna" if inlist(s1q5, "Chuadanga", "Jessore", "Khulna", "Kushtia", "Satkhira")
replace division = "Mymensingh" if inlist(s1q5, "Jamalpur", "Mymensingh", "Sherpur")
replace division = "Rajshahi" if inlist(s1q5, "Bogra", "Nawabganj", "Pabna", "Rajshahi", "Sirajganj")
replace division = "Rangpur" if inlist(s1q5, "Dinajpur", "Lalmonirhat", "Panchagarh", "Rangpur")

encode division, gen(division_code)
tab division_code

keep idno treatment division_code branch_code
isid idno

tempfile bl_merge
save `bl_merge'

*prepare endline
use "${RAW}\STAR+ Endline", clear

gen byte has_consent = (learner_c != "" & learner_c != " ") | (guardian_c != "" & guardian_c != " ")
tab has_consent, m
drop if has_consent == 0
drop has_consent

*income 
gen youth_income = 0

forvalues j = 1/3 {
    cap confirm variable q11col12_`j'
    if !_rc {
        tempvar w`j'
        gen double `w`j'' = cond(q11col4_`j' == 2 & !missing(q11col12_`j'), q11col12_`j', 0)
        replace youth_income = youth_income + `w`j''
    }
    
    cap confirm variable newq11col13_`j'
    if !_rc {
        tempvar s`j'
        gen double `s`j'' = cond(q11col4_`j' == 1 & !missing(newq11col13_`j'), ///
            (cond(!missing(newq11col13_`j'), newq11col13_`j', 0) - ///
             cond(!missing(newq11col14_`j'), newq11col14_`j', 0)) / 12, 0)
        replace youth_income = youth_income + `s`j''
    }
}

replace youth_income = 0 if q911 == 0 & !missing(q911)
label variable youth_income "Youth monthly income (BDT)"
sum youth_income, detail

*employment
gen byte employed = (q911 == 1) if !missing(q911)
label variable employed "Youth employed (=1)"
label define employed 0 "unemployed" 1 "employed"
label values employed employed

keep idno participant youth_income employed

*merge with baseline
merge 1:1 idno using `bl_merge'
tab _merge

keep if _merge == 3
drop _merge

sum youth_income employed treatment participant
tab treatment participant, row


eststo clear
* ITT Income
regress youth_income treatment i.division_code, vce(cluster branch_code)
outreg2 using "$RESULT/itt_late_results.xls", replace ///
    keep(treatment) ///
    addtext(Division FE, Yes) ///
    ctitle("ITT", "Income (BDT)") ///
    label excel

* ITT Employment
regress employed treatment i.division_code, vce(cluster branch_code)
outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(treatment) ///
    addtext(Division FE, Yes) ///
    ctitle("ITT", "Employed (=1)") ///
    label excel

* LATE Income
ivregress 2sls youth_income i.division_code (participant = treatment), vce(cluster branch_code) first
outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(participant) ///
    addtext(Division FE, Yes) ///
    ctitle("LATE", "Income (BDT)") ///
    label excel

* LATE Employment
ivregress 2sls employed i.division_code (participant = treatment), vce(cluster branch_code) first
outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(participant) ///
    addtext(Division FE, Yes) ///
    ctitle("LATE", "Employed (=1)") ///
    label excel
	
**********************************
**#Q6 Controllin Basline Covariate

use "${RAW}\STAR+ Baseline", clear
drop if col2_1 == "" | col2_1 == " " | missing(col2_1)

encode branch, gen(branch_code)

* Division
gen division = ""
replace division = "Barishal" if inlist(s1q5, "Barisal", "Bhola", "Patuakhali")
replace division = "Chattogram" if inlist(s1q5, "Chittagong", "Chandpur", "Comilla", "Brahmanbaria", "Lakshmipur", "Noakhali", "Feni")
replace division = "Dhaka" if inlist(s1q5, "Dhaka", "Gazipur", "Gopalganj", "Kishorgonj", "Madaripur", "Manikganj", "Munshiganj")
replace division = "Dhaka" if inlist(s1q5, "Narayanganj", "Narsingdi", "Rajbari", "Shariatpur", "Tangail")
replace division = "Khulna" if inlist(s1q5, "Chuadanga", "Jessore", "Khulna", "Kushtia", "Satkhira")
replace division = "Mymensingh" if inlist(s1q5, "Jamalpur", "Mymensingh", "Sherpur")
replace division = "Rajshahi" if inlist(s1q5, "Bogra", "Nawabganj", "Pabna", "Rajshahi", "Sirajganj")
replace division = "Rangpur" if inlist(s1q5, "Dinajpur", "Lalmonirhat", "Panchagarh", "Rangpur")
encode division, gen(division_code)


gen youth_age = res_age
label var youth_age "Youth Age (years)"

gen youth_male = (res_gender == "Male")
label var youth_male "Youth is Male"

gen youth_married = (res_marital_code == 2)
label var youth_married "Youth is Married"

gen hh_size = tot_mem
label var hh_size "Household Size"

gen land_amount = q411
label var land_amount "Land Amount"

gen num_cows = q4131
label var num_cows "Number of Cows"

gen num_goats_sheep = q4141
label var num_goats_sheep "Goats/Sheep Owned"

* Household monthly average income
foreach i of numlist 1/4 {
    capture confirm variable q11col12_`i'
    if !_rc {
        replace q11col12_`i' = 0 if missing(q11col12_`i')
    }
}
egen youth_earn = rowtotal(q11col12_1 q11col12_2 q11col12_3 q11col12_4)

foreach m of numlist 1/11 {
    foreach a of numlist 1/3 {
        capture confirm variable q15col9_`m'_`a'
        if !_rc {
            replace q15col9_`m'_`a' = 0 if missing(q15col9_`m'_`a')
        }
    }
}
egen other_earn = rowtotal(q15col9_*_*)
gen monthly_income = youth_earn + other_earn
label variable monthly_income "Household monthly average income (BDT)"


keep idno treatment division_code branch_code  youth_age youth_male youth_married hh_size land_amount num_cows num_goats_sheep monthly_income

tempfile bl_merge_cov
save `bl_merge_cov'


use "${RAW}\STAR+ Endline", clear
gen byte has_consent = (learner_c != "" & learner_c != " ") | (guardian_c != "" & guardian_c != " ")
drop if has_consent == 0
drop has_consent

* Income
gen youth_income = 0
forvalues j = 1/3 {
    cap confirm variable q11col12_`j'
    if !_rc {
        tempvar w`j'
        gen double `w`j'' = cond(q11col4_`j' == 2 & !missing(q11col12_`j'), q11col12_`j', 0)
        replace youth_income = youth_income + `w`j''
    }
    cap confirm variable newq11col13_`j'
    if !_rc {
        tempvar s`j'
        gen double `s`j'' = cond(q11col4_`j' == 1 & !missing(newq11col13_`j'), ///
            (cond(!missing(newq11col13_`j'), newq11col13_`j', 0) - ///
             cond(!missing(newq11col14_`j'), newq11col14_`j', 0)) / 12, 0)
        replace youth_income = youth_income + `s`j''
    }
}
replace youth_income = 0 if q911 == 0 & !missing(q911)
label variable youth_income "Youth monthly income (BDT)"

* Employment
gen byte employed = (q911 == 1) if !missing(q911)
label variable employed "Youth employed (=1)"

keep idno participant youth_income employed


merge 1:1 idno using `bl_merge_cov'
keep if _merge == 3
drop _merge


global bl_covariates "youth_age youth_male youth_married hh_size land_amount num_cows num_goats_sheep monthly_income"


misstable summarize $bl_covariates

* ITT Income + covariates
regress youth_income treatment $bl_covariates i.division_code, vce(cluster branch_code)
outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(treatment $bl_covariates) ///
    addtext(Division FE, Yes, Baseline Covariates, Yes) ///
    ctitle("ITT + Cov", "Income (BDT)") ///
    label excel

* ITT Employment + covariates
regress employed treatment $bl_covariates i.division_code, vce(cluster branch_code)
outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(treatment $bl_covariates) ///
    addtext(Division FE, Yes, Baseline Covariates, Yes) ///
    ctitle("ITT + Cov", "Employed (=1)") ///
    label excel

* LATE Income + covariates
ivregress 2sls youth_income $bl_covariates i.division_code ///
    (participant = treatment), vce(cluster branch_code) first
outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(participant $bl_covariates) ///
    addtext(Division FE, Yes, Baseline Covariates, Yes) ///
    ctitle("LATE + Cov", "Income (BDT)") ///
    label excel

* LATE Employment + covariates
ivregress 2sls employed $bl_covariates i.division_code ///
    (participant = treatment), vce(cluster branch_code) first
outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(participant $bl_covariates) ///
    addtext(Division FE, Yes, Baseline Covariates, Yes) ///
    ctitle("LATE + Cov", "Employed (=1)") ///
    label excel	
	
**********************************
**#Q7 Heterogenery analysis

* Generate interaction terms
gen treat_male = treatment * youth_male
label var treat_male "Treatment × Male"

gen parti_male = participant * youth_male
label var parti_male "Participant × Male"

* Covariates excluding youth_male 
global bl_covariates_g "youth_age youth_married hh_size land_amount num_cows num_goats_sheep monthly_income"

* ITT: Income
regress youth_income treatment youth_male treat_male $bl_covariates_g i.division_code, vce(cluster branch_code)

outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(treatment youth_male treat_male $bl_covariates_g) ///
    addtext(Division FE, Yes, Baseline Covariates, Yes) ///
    ctitle("ITT Gender", "Income (BDT)") ///
    label excel

* ITT: Employment 
regress employed treatment youth_male treat_male $bl_covariates_g i.division_code, vce(cluster branch_code)

outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(treatment youth_male treat_male $bl_covariates_g) ///
    addtext(Division FE, Yes, Baseline Covariates, Yes) ///
    ctitle("ITT Gender", "Employed (=1)") ///
    label excel

* LATE: Income 
ivregress 2sls youth_income youth_male $bl_covariates_g i.division_code (participant parti_male = treatment treat_male), vce(cluster branch_code) first

outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(participant youth_male parti_male $bl_covariates_g) ///
    addtext(Division FE, Yes, Baseline Covariates, Yes) ///
    ctitle("LATE Gender", "Income (BDT)") ///
    label excel

* LATE: Employment 
ivregress 2sls employed youth_male $bl_covariates_g i.division_code ///
    (participant parti_male = treatment treat_male), ///
    vce(cluster branch_code) first

outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(participant youth_male parti_male $bl_covariates_g) ///
    addtext(Division FE, Yes, Baseline Covariates, Yes) ///
    ctitle("LATE Gender", "Employed (=1)") ///
    label excel



* ITT Income + covariates
regress youth_income treatment $bl_covariates i.division_code, vce(cluster branch_code)
outreg2 using "$RESULT/itt_late_results.xls", append keep(treatment $bl_covariates) ///
    addtext(Division FE, Yes, Baseline Covariates, Yes) ///
    ctitle("ITT + Cov", "Income (BDT)") ///
    label excel

* ITT Employment + covariates
regress employed treatment $bl_covariates i.division_code, vce(cluster branch_code)
outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(treatment $bl_covariates) ///
    addtext(Division FE, Yes, Baseline Covariates, Yes) ///
    ctitle("ITT + Cov", "Employed (=1)") ///
    label excel

* LATE Income + covariates
ivregress 2sls youth_income $bl_covariates i.division_code ///
    (participant = treatment), vce(cluster branch_code) first
outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(participant $bl_covariates) ///
    addtext(Division FE, Yes, Baseline Covariates, Yes) ///
    ctitle("LATE + Cov", "Income (BDT)") ///
    label excel

* LATE Employment + covariates
ivregress 2sls employed $bl_covariates i.division_code ///
    (participant = treatment), vce(cluster branch_code) first
outreg2 using "$RESULT/itt_late_results.xls", append ///
    keep(participant $bl_covariates) ///
    addtext(Division FE, Yes, Baseline Covariates, Yes) ///
    ctitle("LATE + Cov", "Employed (=1)") ///
    label excel	
	
**********************************
**#Q8 DID FE

use "${RAW}\STAR+ Baseline", clear
drop if col2_1 == "" | col2_1 == " " | missing(col2_1)

encode branch, gen(branch_code)

* Division
gen division = ""
replace division = "Barishal" if inlist(s1q5, "Barisal", "Bhola", "Patuakhali")
replace division = "Chattogram" if inlist(s1q5, "Chittagong", "Chandpur", "Comilla", "Brahmanbaria", "Lakshmipur", "Noakhali", "Feni")
replace division = "Dhaka" if inlist(s1q5, "Dhaka", "Gazipur", "Gopalganj", "Kishorgonj", "Madaripur", "Manikganj", "Munshiganj")
replace division = "Dhaka" if inlist(s1q5, "Narayanganj", "Narsingdi", "Rajbari", "Shariatpur", "Tangail")
replace division = "Khulna" if inlist(s1q5, "Chuadanga", "Jessore", "Khulna", "Kushtia", "Satkhira")
replace division = "Mymensingh" if inlist(s1q5, "Jamalpur", "Mymensingh", "Sherpur")
replace division = "Rajshahi" if inlist(s1q5, "Bogra", "Nawabganj", "Pabna", "Rajshahi", "Sirajganj")
replace division = "Rangpur" if inlist(s1q5, "Dinajpur", "Lalmonirhat", "Panchagarh", "Rangpur")
encode division, gen(division_code)

* Baseline income
foreach i of numlist 1/3 {
    capture confirm variable q11col12_`i'
    if !_rc {
        replace q11col12_`i' = 0 if missing(q11col12_`i')
    }
}
egen youth_income_0 = rowtotal(q11col12_1 q11col12_2 q11col12_3)
replace youth_income_0 = 0 if q911 == 0 & !missing(q911)
label variable youth_income_0 "Youth monthly income - Baseline"

keep idno treatment division_code branch_code youth_income_0

tempfile bl_wide
save `bl_wide'

use "${RAW}\STAR+ Endline", clear

gen byte has_consent = (learner_c != "" & learner_c != " ") | ///
                       (guardian_c != "" & guardian_c != " ")
drop if has_consent == 0
drop has_consent

* Endline income
gen youth_income_1 = 0

forvalues j = 1/3 {
    cap confirm variable q11col12_`j'
    if !_rc {
        tempvar w`j'
        gen double `w`j'' = cond(q11col4_`j' == 2 & !missing(q11col12_`j'), ///
                                 q11col12_`j', 0)
        replace youth_income_1 = youth_income_1 + `w`j''
    }
    cap confirm variable newq11col13_`j'
    if !_rc {
        tempvar s`j'
        gen double `s`j'' = cond(q11col4_`j' == 1 & !missing(newq11col13_`j'), ///
            (cond(!missing(newq11col13_`j'), newq11col13_`j', 0) - ///
             cond(!missing(newq11col14_`j'), newq11col14_`j', 0)) / 12, 0)
        replace youth_income_1 = youth_income_1 + `s`j''
    }
}
replace youth_income_1 = 0 if q911 == 0 & !missing(q911)
label variable youth_income_1 "Youth monthly income - Endline"

keep idno youth_income_1

merge 1:1 idno using `bl_wide'
tab _merge
keep if _merge == 3
drop _merge


list idno treatment youth_income_0 youth_income_1 in 1/5



reshape long youth_income_, i(idno treatment division_code branch_code) j(time)
rename youth_income_ youth_income

label variable youth_income "Youth monthly income (BDT)"
label variable time "Period (0=Baseline, 1=Endline)"
label define time_lbl 0 "Baseline" 1 "Endline"
label values time time_lbl


isid idno time
xtset idno time

* Create DiD interaction 
gen treat_post = treatment * time
label variable treat_post "Treatment × Post"

* Descriptives
bysort time: sum youth_income
tab treatment time, sum(youth_income) mean


*DiD

regress youth_income treatment time treat_post i.division_code, vce(cluster branch_code)

outreg2 using "$RESULT/did_fe_results.xls", replace ///
    keep(treatment time treat_post) ///
    addtext(Division FE, Yes, Individual FE, No) ///
    ctitle("DiD", "Income (BDT)") ///
    label excel


*FE

xtreg youth_income time treat_post i.division_code, fe vce(cluster branch_code)

outreg2 using "$RESULT/did_fe_results.xls", append ///
    keep(time treat_post) ///
    addtext(Division FE, Yes, Individual FE, Yes) ///
    ctitle("FE", "Income (BDT)") ///
    label excel
	
*** DiD analysis shows no significant treatment effect on income (-47.12 BDT, p>0.1) despite strong period effect (+405.2***, p<0.01), robust across both DiD and individual FE specifications (N=990, 495 individuals)
	
