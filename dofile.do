log using "filepath.log", replace


*************************************************************************************************************************
***                                                                                                                   *** 
***     Impact of the Affordable Care Act Medicaid Expansion on Routine Medical Checkups Among Low-Income Adults      ***
***                                                                                                                   *** 
*************************************************************************************************************************

clear all
clear matrix
label drop _all
set more off

*************************************************************************************************************************

global projACA  "filepath"
global raw    "$projACA/raw"
global clean  "$projACA/clean"
global temp   "$projACA/temp"
global master "$projACA/master"
global graphs "$projACA/graphs"
global log    "$projACA/log"

local keepvars id year imonth _state age sex race_g marital _educag income2 ///
    mscode checkup1 hlthpln1 _chldcnt employ _llcpwt _psu _ststr

*** Importing ***
*************************************************************************************************************************

foreach y of numlist 2011/2016 {
	    
    import sasxport5 "$raw/LLCP`y'.XPT", clear
    compress
    rename *, lower
    
    gen year = `y'
    gen id = _n
    
    *** Year-specific Renaming ***
	if `y' == 2011 | `y' == 2012 {
        rename _race_g race_g
    }
    else {
        rename (_age80 _race_g1 employ1) (age race_g employ)
    }
    
    keep `keepvars'
    save "$raw/`y'", replace
}

*** Appending ***
*************************************************************************************************************************

use "$raw/2011", clear
foreach y of numlist 2012/2016 {
    append using "$raw/`y'"
}

save "$raw/2011_2016", replace


******** Recoding ********
*************************************************************************************************************************

use "$raw/2011_2016", clear

*** Checks for missing ***
foreach v in age sex race_g marital _educag income2 _chldcnt employ ///
             year imonth _state mscode checkup1 hlthpln1 {
    tab `v', missing
}


*** Demographic variables ***
*************************************************************************************************************************

* Restrict sample to adults age 19-64
recode age ///
    (19/24 = 1 "19-24") ///
    (25/29 = 2 "25-29") ///
    (30/34 = 3 "30-34") ///
    (35/39 = 4 "35-39") ///
    (40/44 = 5 "40-44") ///
    (45/49 = 6 "45-49") ///
    (50/54 = 7 "50-54") ///
    (55/59 = 8 "55-59") ///
    (60/64 = 9 "60-64") ///
    (else = .), gen(age_cat)
drop if age_cat == .

recode sex ///
    (1 = 0 "Male") ///
    (2 = 1 "Female") ///
    (else = .), gen(female)

recode race_g ///
    (1 = 1 "Non-Hispanic White") ///
    (2 = 2 "Non-Hispanic Black") ///
    (3 = 3 "Hispanic") ///
    (4/5 = 0 "Other") ///
    (else = .), gen(race)

recode marital ///
    (1 = 1 "Married") ///
    (2/6 = 0 "Others") ///
    (else = .), gen(marital_status)

recode _educag ///
    (1 = 1 "No High School") ///
    (2 = 2 "High School") ///
    (3 = 3 "Some College") ///
    (4 = 4 "College Grad") ///
    (else = .), gen(educa_lvl)


*** Socioeconomic variables ***
*************************************************************************************************************************

recode income2 ///
    (1 = 1 "Less than $10k") ///
    (2 = 2 "$10k-$15k") ///
    (3 = 3 "$15k-$20k") ///
    (4 = 4 "$20k-$25k") ///
    (5 = 5 "$25k-$35k") ///
    (6 = 6 "$35k-$50k") ///
    (7 = 7 "$50k-$75k") ///
    (8 = 8 "More than $75k") ///
    (else = .), gen(income_cat)

recode employ ///
    (1/2 = 1 "Employed") ///
    (3/4 = 0 "Unemployed") ///
    (5/8 = 2 "Others") ///
    (else = .), gen(employ_status)

recode hlthpln1 ///
    (1 = 1 "Insured") ///
    (2 = 0 "Uninsured") ///
    (else = .), gen(insured)


*** Children and household size ***
*************************************************************************************************************************

recode _chldcnt ///
    (1 = 0 "No children") ///
    (2 = 1 "One child") ///
    (3 = 2 "Two children") ///
    (4 = 3 "Three children") ///
    (5 = 4 "Four children") ///
    (6 = 5 "Five+ children") ///
    (else = .), gen(num_children)

gen hhsize = .
replace hhsize = num_children + 2 if marital_status == 1
replace hhsize = num_children + 1 if marital_status == 0
label var hhsize "Estimated household size"

*** States ***
*************************************************************************************************************************

label define state_lbl ///
    1 "Alabama" 2 "Alaska" 4 "Arizona" 5 "Arkansas" 6 "California" ///
    8 "Colorado" 9 "Connecticut" 10 "Delaware" 11 "District of Columbia" ///
    12 "Florida" 13 "Georgia" 15 "Hawaii" 16 "Idaho" 17 "Illinois" ///
    18 "Indiana" 19 "Iowa" 20 "Kansas" 21 "Kentucky" 22 "Louisiana" ///
    23 "Maine" 24 "Maryland" 25 "Massachusetts" 26 "Michigan" ///
    27 "Minnesota" 28 "Mississippi" 29 "Missouri" 30 "Montana" ///
    31 "Nebraska" 32 "Nevada" 33 "New Hampshire" 34 "New Jersey" ///
    35 "New Mexico" 36 "New York" 37 "North Carolina" 38 "North Dakota" ///
    39 "Ohio" 40 "Oklahoma" 41 "Oregon" 42 "Pennsylvania" 44 "Rhode Island" ///
    45 "South Carolina" 46 "South Dakota" 47 "Tennessee" 48 "Texas" ///
    49 "Utah" 50 "Vermont" 51 "Virginia" 53 "Washington" ///
    54 "West Virginia" 55 "Wisconsin" 56 "Wyoming" ///
    66 "Guam" 72 "Puerto Rico"
label values _state state_lbl

drop if inlist(_state, 66, 72, 78)

recode mscode ///
    (1/2 = 1 "Urban") ///
    (3/4 = 2 "Suburban") ///
    (5   = 3 "Rural") ///
    (else = .), gen(msa_status)


*** Outcome variable ***
*************************************************************************************************************************

replace checkup1 = . if inlist(checkup1, 7, 9)

gen checkup_1year = (checkup1 == 1) if !missing(checkup1)
label var checkup_1year "Had checkup in past year"
label define checkup1yr_lbl 0 "No" 1 "Yes"
label values checkup_1year checkup1yr_lbl


*** Medicaid expansion year ***
*************************************************************************************************************************

gen expand_year = .
replace expand_year = 2014 if inlist(_state, 4,5,6,8,9,10,11,15,17,19,21,24,25,27,32,34,35,36,38,39,41,44,50,53,54)
replace expand_year = 2014 if inlist(_state, 26,33)
replace expand_year = 2015 if inlist(_state, 2,18,42)
replace expand_year = 2016 if inlist(_state, 22,30)

gen mexpansion = !missing(expand_year)
label define medexp_lbl 0 "Non-expansion" 1 "Expansion"
label values mexpansion medexp_lbl

*** Checks for sample size and missing ***
*************************************************************************************************************************

tab checkup_1year year, missing
tab mexpansion year, missing
tab marital_status hhsize, missing

save "$clean/r2011_2016", replace
save "$temp/r2011_2016", replace


*** Merging ***
*************************************************************************************************************************

use "$temp/r2011_2016", clear

merge m:1 _state year using "$temp/medicaid_exp_2011_2016.dta"
keep if _merge == 3
drop _merge
save "$temp/medicaid2011_2016", replace

use "$temp/medicaid2011_2016", clear

merge m:1 hhsize using "$temp/poverty2013.dta"
keep if _merge == 3
drop _merge

save "$temp/m2011_2016", replace
save "$master/m2011_2016", replace


*** Analysis begin ***
*************************************************************************************************************************

use "$master/m2011_2016", clear

rename medicaid_exp post
rename mexpansion   medicaid


*** Income and FPL ***
*************************************************************************************************************************

gen income_mid = .
replace income_mid =  7500 if income_cat == 1
replace income_mid = 12500 if income_cat == 2
replace income_mid = 17500 if income_cat == 3
replace income_mid = 22500 if income_cat == 4
replace income_mid = 30000 if income_cat == 5
replace income_mid = 42500 if income_cat == 6
replace income_mid = 62500 if income_cat == 7
replace income_mid = 87500 if income_cat == 8

gen fpl_threshold = fpl
replace fpl_threshold = fplhi if _state == 15
replace fpl_threshold = fplak if _state == 2

gen fpl_pct = 100 * income_mid / fpl_threshold

gen low_income = fpl_pct <= 138 if !missing(fpl_pct)
label define lowinc_lbl 0 ">138% FPL" 1 "<=138% FPL"
label values low_income lowinc_lbl
label var low_income "Income at or below 138% FPL"



*** Table 1 dummy variables ***
*************************************************************************************************************************

* Age: 19-24 omitted
gen age25_29 = age_cat == 2 if !missing(age_cat)
gen age30_34 = age_cat == 3 if !missing(age_cat)
gen age35_39 = age_cat == 4 if !missing(age_cat)
gen age40_44 = age_cat == 5 if !missing(age_cat)
gen age45_49 = age_cat == 6 if !missing(age_cat)
gen age50_54 = age_cat == 7 if !missing(age_cat)
gen age55_59 = age_cat == 8 if !missing(age_cat)
gen age60_64 = age_cat == 9 if !missing(age_cat)

* Race
gen black    = race == 2 if !missing(race)
gen hispanic = race == 3 if !missing(race)
gen white    = race == 1 if !missing(race)

* Marital status
gen married = marital_status == 1 if !missing(marital_status)

* Education: <HS omitted
gen hsdegree    = educa_lvl == 2 if !missing(educa_lvl)
gen somecollege = educa_lvl == 3 if !missing(educa_lvl)
gen collegegrad = educa_lvl == 4 if !missing(educa_lvl)

* Children: 0 omitted
gen onechild      = num_children == 1 if !missing(num_children)
gen twochildren   = num_children == 2 if !missing(num_children)
gen threechildren = num_children == 3 if !missing(num_children)
gen fourchildren  = num_children == 4 if !missing(num_children)

* Employment
gen unemployed = employ_status == 0 if !missing(employ_status)
gen student    = employ == 6 if !missing(employ)

* Income: <10k omitted
gen inc10_15 = income_cat == 2 if !missing(income_cat)
gen inc15_20 = income_cat == 3 if !missing(income_cat)
gen inc20_25 = income_cat == 4 if !missing(income_cat)
gen inc25_35 = income_cat == 5 if !missing(income_cat)
gen inc35_50 = income_cat == 6 if !missing(income_cat)
gen inc50_75 = income_cat == 7 if !missing(income_cat)
gen inc75p   = income_cat == 8 if !missing(income_cat)


*** Group variables ***
*************************************************************************************************************************
gen income_exp_group = .
replace income_exp_group = 1 if low_income == 1 & medicaid == 1
replace income_exp_group = 2 if low_income == 1 & medicaid == 0
replace income_exp_group = 3 if low_income == 0 & medicaid == 1
replace income_exp_group = 4 if low_income == 0 & medicaid == 0

label define income_exp_group_lbl ///
    1 "Low income, Expansion state" ///
    2 "Low income, Non-expansion state" ///
    3 "High income, Expansion state" ///
    4 "High income, Non-expansion state"
label values income_exp_group income_exp_group_lbl

gen ins_exp_group = .
replace ins_exp_group = 1 if insured == 1 & medicaid == 1
replace ins_exp_group = 2 if insured == 0 & medicaid == 1
replace ins_exp_group = 3 if insured == 1 & medicaid == 0
replace ins_exp_group = 4 if insured == 0 & medicaid == 0

label define ins_exp_group_lbl ///
    1 "Insured, Expansion" ///
    2 "Uninsured, Expansion" ///
    3 "Insured, Non-expansion" ///
    4 "Uninsured, Non-expansion"
label values ins_exp_group ins_exp_group_lbl


*** Labeling ***
*************************************************************************************************************************

label var checkup_1year "Check-up in past year"

label var age25_29 "Age 25-29"
label var age30_34 "Age 30-34"
label var age35_39 "Age 35-39"
label var age40_44 "Age 40-44"
label var age45_49 "Age 45-49"
label var age50_54 "Age 50-54"
label var age55_59 "Age 55-59"
label var age60_64 "Age 60-64"

label var female "Female"
label var black "Black"
label var hispanic "Hispanic"
label var white "White"
label var married "Married"

label var hsdegree "High school degree"
label var somecollege "Some college"
label var collegegrad "College graduate"

label var onechild "One child"
label var twochildren "Two children"
label var threechildren "Three children"
label var fourchildren "Four children"

label var unemployed "Unemployed"
label var student "Student"

label var inc10_15 "Income $10k-$15k"
label var inc15_20 "Income $15k-$20k"
label var inc20_25 "Income $20k-$25k"
label var inc25_35 "Income $25k-$35k"
label var inc35_50 "Income $35k-$50k"
label var inc50_75 "Income $50k-$75k"
label var inc75p   "Income >$75k"

save "$master/d2011_2016", replace

*** Figures ***
*************************************************************************************************************************

use "$master/d2011_2016", clear

svyset _psu [pweight=_llcpwt], strata(_ststr)

* Annual checkup rate over time
preserve
collapse (mean) checkup_1year, by(year)

twoway ///
    (connected checkup_1year year, ///
        lcolor(black) lwidth(medthick) ///
        msymbol(oh) mcolor(black) msize(small)), ///
    xline(2014, lpattern(shortdash) lcolor(gs10)) ///
    xlabel(2011(1)2016, nogrid) ///
    ylabel(, nogrid format(%9.2f)) ///
    title("Annual Checkup Rate Over Time") ///
    xtitle("Year") ///
    ytitle("Checkup in Past Year") ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    scheme(s2mono)

graph export "$graphs/checkup_trend.png", replace width(2000)
restore

* Checkup among low-income adults by expansion status
preserve
collapse (mean) checkup_1year [aw=_llcpwt], by(year income_exp_group)

twoway ///
    (connected checkup_1year year if income_exp_group == 1, ///
        lcolor(black) lwidth(medthick) lpattern(solid) ///
        msymbol(circle) mcolor(black) msize(small)) ///
    (connected checkup_1year year if income_exp_group == 2, ///
        lcolor(black) lwidth(medthin) lpattern(dash) ///
        msymbol(square) mcolor(black) msize(small)), ///
    xline(2014, lpattern(solid) lcolor(gs10)) ///
    xlabel(2011(1)2016, nogrid) ///
    ylabel(, nogrid format(%9.2f)) ///
    title("Check-up Among Low-Income Adults") ///
    xtitle("Year") ///
    ytitle("") ///
    legend(order(1 "Expansion States" 2 "Non-Expansion States") pos(6) row(1)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    scheme(s2mono)

graph export "$graphs/checkup_trend_lowinc.png", replace width(2000)
restore

* Checkup by expansion status (full income sample)
preserve
collapse (mean) checkup_1year [aw=_llcpwt], by(year medicaid)

twoway ///
    (connected checkup_1year year if medicaid == 1, ///
        lcolor(black) lwidth(medthick) lpattern(solid) ///
        msymbol(circle) mcolor(black) msize(small)) ///
    (connected checkup_1year year if medicaid == 0, ///
        lcolor(black) lwidth(medthin) lpattern(dash) ///
        msymbol(square) mcolor(black) msize(small)), ///
    xlabel(2011(1)2016, nogrid) ///
    ylabel(, nogrid format(%9.2f)) ///
    title("Check-up by Expansion Status") ///
    xtitle("Year") ///
    ytitle("") ///
    legend(order(1 "Expansion States" 2 "Non-Expansion States") pos(6) row(1)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    scheme(s2mono)

graph export "$graphs/checkup_trend_by_expansion.png", replace width(2000)
restore

* Checkup by income and expansion status
preserve
keep if !missing(income_exp_group)
collapse (mean) checkup_1year [aw=_llcpwt], by(year income_exp_group)

twoway ///
    (connected checkup_1year year if income_exp_group == 1, ///
        lcolor(black) lwidth(medthick) msymbol(circle) mcolor(black)) ///
    (connected checkup_1year year if income_exp_group == 2, ///
        lcolor(gray) lwidth(medthin) msymbol(square) mcolor(gray)) ///
    (connected checkup_1year year if income_exp_group == 3, ///
        lcolor(gray) lwidth(medthin) lpattern(dash) ///
        msymbol(triangle) mcolor(gray)) ///
    (connected checkup_1year year if income_exp_group == 4, ///
        lcolor(gray) lwidth(medthin) lpattern(dash) ///
        msymbol(diamond) mcolor(gray)), ///
    xlabel(2011(1)2016, nogrid) ///
    ylabel(, nogrid format(%9.2f)) ///
    title("Annual Checkup Rate by Income and Expansion Status") ///
    xtitle("Year") ///
    ytitle("Checkup in Past Year") ///
    legend(order(1 "Low income, Expansion" ///
                 2 "Low income, Non-expansion" ///
                 3 "High income, Expansion" ///
                 4 "High income, Non-expansion") ///
           pos(6) row(2)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    scheme(s2mono)

graph export "$graphs/checkup_trend_by_income.png", replace width(2000)
restore

* Checkup by insurance and expansion status
preserve
collapse (mean) checkup_1year [aw=_llcpwt], by(year ins_exp_group)

twoway ///
    (connected checkup_1year year if ins_exp_group == 1, ///
        lcolor(black) lwidth(medthin) lpattern(dash) ///
        msymbol(circle) mcolor(black)) ///
    (connected checkup_1year year if ins_exp_group == 2, ///
        lcolor(gray) lwidth(medthick) lpattern(solid) ///
        msymbol(square) mcolor(gray)) ///
    (connected checkup_1year year if ins_exp_group == 3, ///
        lcolor(gray) lwidth(medthin) lpattern(dash) ///
        msymbol(triangle) mcolor(gray)) ///
    (connected checkup_1year year if ins_exp_group == 4, ///
        lcolor(gray) lwidth(medthin) lpattern(dash) ///
        msymbol(diamond) mcolor(gray)), ///
    xlabel(2011(1)2016, nogrid) ///
    ylabel(, nogrid format(%9.2f)) ///
    title("Annual Checkup Rate by Insurance and Expansion Status") ///
    xtitle("Year") ///
    ytitle("Checkup in Past Year") ///
    legend(order(1 "Insured, Expansion" ///
                 2 "Uninsured, Expansion" ///
                 3 "Insured, Non-expansion" ///
                 4 "Uninsured, Non-expansion") ///
           pos(6) row(2)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    scheme(s2mono)

graph export "$graphs/checkup_trend_by_insuranceStat.png", replace
restore

*** Tables ***
*************************************************************************************************************************

*** Descriptive statistics ***
*************************************************************************************************************************

use "$master/d2011_2016", clear

svyset _psu [pweight=_llcpwt], strata(_ststr)

tab checkup_1year year, col


keep if low_income == 1


tab checkup_1year year, col

gen group = .
replace group = 1 if post == 0
replace group = 2 if post == 1

label define group_lbl ///
    1 "Full_pre" ///
    2 "Full_post" 
label values group group_lbl

gen group_sub = .
replace group_sub = 3 if medicaid == 1 & post == 0
replace group_sub = 4 if medicaid == 1 & post == 1
replace group_sub = 5 if medicaid == 0 & post == 0
replace group_sub = 6 if medicaid == 0 & post == 1

label define group_sub_lbl ///
    3 "Pre non-expansion" ///
    4 "Post non-expansion" ///
	5 "Pre non-expansion" ///
    6 "Post non-expansion"
label values group_sub group_sub_lbl

local table1vars ///
    checkup_1year ///
    age25_29 age30_34 age35_39 age40_44 age45_49 age50_54 age55_59 age60_64 ///
    female black hispanic white married ///
    hsdegree somecollege collegegrad ///
    onechild twochildren threechildren fourchildren ///
    unemployed student ///
    inc10_15 inc15_20 inc20_25 inc25_35 inc35_50 inc50_75 inc75p

eststo clear

qui estpost summarize `table1vars' if group == 1 [aw=_llcpwt]
eststo full_pre

qui estpost summarize `table1vars' if group == 2 [aw=_llcpwt]
eststo full_post

qui estpost summarize `table1vars' if group_sub == 3 [aw=_llcpwt]
eststo pre_exp

qui estpost summarize `table1vars' if group_sub == 4 [aw=_llcpwt]
eststo post_exp

qui estpost summarize `table1vars' if group_sub == 5 [aw=_llcpwt]
eststo pre_nonexp

qui estpost summarize `table1vars' if group_sub == 6 [aw=_llcpwt]
eststo post_nonexp
	
esttab full_pre full_post pre_exp post_exp pre_nonexp post_nonexp, ///
    label nonumber noobs compress ///
    cells("mean(fmt(3)) sd(par fmt(3)) count(fmt(0))") ///
	stats(N, fmt(0) labels("Sample size")) ///
    mtitles("Pre" "Post" "Pre" "Post" "Pre" "Post") ///
	mgroups("Full sample" "Medicaid expansion" "Non-expansion", pattern(1 0 1 0 1 0)) ///
    title("Table 1 Descriptive Statistics: Low-Income Adults")

esttab full_pre full_post pre_exp post_exp pre_nonexp post_nonexp ///
	using "$log/table1_prepost.csv", replace ///
    label nonumber noobs compress ///
    cells("mean(fmt(3)) sd(par fmt(3))") ///
	stats(N, fmt(0) labels("Sample size")) ///
    mtitles("Pre" "Post" "Pre" "Post" "Pre" "Post") ///
	mgroups("Full sample" "Medicaid expansion" "Non-expansion", pattern(1 0 1 0 1 0)) ///
    title("Table 1 Descriptive Statistics: Low-Income Adults")


*** Difference-in-differences model ***
*************************************************************************************************************************

gen DiD = medicaid * post

eststo clear
reghdfe checkup_1year DiD i.age_cat female i.race i.marital_status ///
    i.educa_lvl i.income_cat i.num_children unemployed student ///
    [pw=_llcpwt], absorb(_state year) vce(cluster _state)

eststo lowinc

esttab lowinc, replace ///
keep(DiD) b(%9.3f) se(%9.3f)star(* 0.10 ** 0.05 *** 0.01)

esttab lowinc using "$log/FullDiD_checkup_lowinc.csv", replace

esttab lowinc using "$log/OnlyDiD_checkup_lowinc.csv", replace ///
keep(DiD) b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01)


*** Event-study model ***
*************************************************************************************************************************

gen med_yr2011 = medicaid * (year == 2011)
gen med_yr2012 = medicaid * (year == 2012)
gen med_yr2014 = medicaid * (year == 2014)
gen med_yr2015 = medicaid * (year == 2015)
gen med_yr2016 = medicaid * (year == 2016)

eststo clear
reghdfe checkup_1year med_yr2011 med_yr2012 med_yr2014 med_yr2015 med_yr2016 ///
    i.age_cat female i.race i.marital_status i.educa_lvl i.income_cat ///
    i.num_children unemployed student ///
    [pw=_llcpwt] if low_income == 1, absorb(_state year) vce(cluster _state)

eststo eventstudy

esttab eventstudy ///
    using "$log/eventstudy_checkup_lowinc.csv", replace ///
    keep(med_yr2011 med_yr2012 med_yr2014 med_yr2015 med_yr2016) ///
    b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Event-study low-income group")

esttab eventstudy ///
    using "$log/fulleventstudy_checkup_lowinc.csv", replace ///
    b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Full Event-study low-income group")

	
*** Checks for the difference between descriptive and regression sample size ***
*************************************************************************************************************************

count if low_income == 1
count if low_income == 1 & !missing(checkup_1year, DiD, age_cat, female, race, marital_status, educa_lvl, income_cat, num_children, unemployed, student, _llcpwt, _state, year)
	

save "$master/t2011_2016", replace


*** Event-study coefficient plot ***
*************************************************************************************************************************

use "$master/t2011_2016", clear

preserve
clear
input year b se
2011 . .
2012 . .
2013 0 0
2014 . .
2015 . .
2016 . .
end

replace b  = _b[med_yr2011] in 1
replace se = _se[med_yr2011] in 1
replace b  = _b[med_yr2012] in 2
replace se = _se[med_yr2012] in 2
replace b  = _b[med_yr2014] in 4
replace se = _se[med_yr2014] in 4
replace b  = _b[med_yr2015] in 5
replace se = _se[med_yr2015] in 5
replace b  = _b[med_yr2016] in 6
replace se = _se[med_yr2016] in 6

gen lb = b - 1.96 * se
gen ub = b + 1.96 * se

twoway ///
    (line ub year, lcolor(black) lpattern(dash) lwidth(medthin)) ///
    (line lb year, lcolor(black) lpattern(dash) lwidth(medthin)) ///
    (connected b year, lcolor(black) lpattern(solid) lwidth(medium) ///
        msymbol(circle) mcolor(black) msize(medium)), ///
    yline(0, lpattern(solid) lcolor(gs8) lwidth(thin)) ///
    xline(2014, lpattern(solid) lcolor(gs8) lwidth(thin)) ///
    xlabel(2011(1)2016) ///
    ylabel(, format(%9.2f)) ///
    xtitle("Year") ///
    ytitle("Coefficient Estimate") ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    scheme(s2mono)

graph export "$graphs/eventstudy_checkup_lowinc.png", replace width(2000)
restore

log close
