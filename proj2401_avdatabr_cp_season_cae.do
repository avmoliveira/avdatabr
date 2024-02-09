/*-------------------------------------------
STUDY  : Airline Price Seasonality
DATA   : avdatabr_cp_cae
SOURCE : Center for Airline Economics
URL    : https://doi.org/10.7910/DVN/CRYXUZ
--------------------------------------------*/

*----------------------------
*initial stata setup
*----------------------------
/* The stata user-written modules below are necessary 
for executing some commands in this do-file. */

*esttab
net install st0085_2, replace
help esttab

*coefplot
net install gr0059_1, replace
help coefplot


*----------------------------
*open avdatabr_cp_cae
*----------------------------
*import dataset
import delimited ///
https://dataverse.harvard.edu/api/access/datafile/avdatabr_cp_cae/8171526, ///
case(preserve) clear


*----------------------------
*sample selection
*----------------------------
keep if Year>=2013 
gen mean_aircsize = nr_available_seats/nr_departures
summ mean_aircsize
drop if mean_aircsize<50

*remove very unbalanced panels (< 5 years)
bysort CityPair: gen nr_panels = [_N]
summ nr_panels
drop if nr_panels<60


*----------------
*declare panel
*----------------
egen k = group(CityPair)
egen t = group(YearMonth)
tsset k t


*----------------
*variables
*----------------
gen AirFare = ln(price)
gen Distance = ln(km_great_circle_distance)
gen FuelPrice = ln(jetfuel_price_org)
gen PaxDens = ln(nr_revenue_pax)
gen MktConc = ln(market_concentration_hhi*10000)
gen LoadFactor = ln(pc_load_factor)
gen Pandemic = (YearMonth>=202002 & YearMonth<=202204)
gen Trend = t/60


*----------------
*seasonality
*----------------
gen WintBreak = (Month==7)
gen SummBrSearch = (Month==8 | Month==9 | Month==10 | Month==11)
gen SummBreak = (Month==12 | Month==1 | Month==2) // base case = 3
gen LowSeason = (Month==4 | Month==5 | Month==6)


*-------------------------
*Experiment n. 1
*Simple seasonality controls
*-------------------------

*FE without seasonality
xtreg AirFare FuelPrice PaxDens MktConc LoadFactor ///
	Pandemic Trend, fe

est store FE1

*FE with seasonality
xtreg AirFare FuelPrice PaxDens MktConc LoadFactor ///
	Pandemic Trend WintBreak SummBrSearch SummBreak LowSeason, fe

est store FE2

*show results table
esttab 	FE1 FE2 ///
		, nocons nose not nogaps noobs ///
		b(%9.4f) varwidth(14) brackets ///
		addnote("Notes: Fixed Effect estimation")


*-------------------------
*Experiment n. 2
*more granular seasonality
*-------------------------
gen SummBreak_m4 = (Month==8)
gen SummBreak_m3 = (Month==9)
gen SummBreak_m2 = (Month==10)
gen SummBreak_m1 = (Month==11)
gen SummBreak_p0 = (Month==12)
gen SummBreak_p1 = (Month==1)
gen SummBreak_p2 = (Month==2)
gen LowSeason_p1 = (Month==4) // base case p0
gen LowSeason_p2 = (Month==5)
gen LowSeason_p3 = (Month==6)


*FE with seasonality
xtreg AirFare FuelPrice PaxDens MktConc LoadFactor ///
	Pandemic Trend WintBreak SummBreak_m* SummBreak_p* LowSeason_p*, fe

est store FE3

*show results table
esttab 	FE3 ///
		, nocons nose not nogaps noobs ///
		b(%9.4f) varwidth(14) brackets ///
		addnote("Notes: Fixed Effect estimation")



*-------------------------
*Experiment n. 3
*Pandemic effect
*-------------------------

*Before Pandemic
xtreg AirFare FuelPrice PaxDens MktConc LoadFactor ///
	Pandemic Trend WintBreak SummBreak_m* SummBreak_p* LowSeason_p* ///
	if YearMonth<=202001, fe

est store PrePandemic

*Post Pandemic
xtreg AirFare FuelPrice PaxDens MktConc LoadFactor ///
	Pandemic Trend WintBreak SummBreak_m* SummBreak_p* LowSeason_p* ///
	if YearMonth>=202205, fe

est store PostPandemic

*show results table
esttab 	PrePandemic PostPandemic ///
		, nocons nose not nogaps noobs ///
		b(%9.4f) varwidth(14) brackets ///
		addnote("Notes: Fixed Effect estimation")

*Coefficient Plot
ds WintBreak SummBreak_m* SummBreak_p* LowSeason_p*
coefplot PrePandemic PostPandemic, keep(`r(varlist)') ///
		 xline(0, lcolor(green) lpattern(dash)) scheme(s2color)








    