/*-------------------------------------------
STUDY  : Airline Price Seasonality
DATA   : avdatabr_cp_cae
SOURCE : Center for Airline Economics
URL    : https://doi.org/10.7910/DVN/CRYXUZ
--------------------------------------------*/
*This code requires Stata 14 or higher

*----------------------------
*initial stata setup
*----------------------------
/* The stata user-written modules below are necessary 
for executing some commands in this do-file. */

*fsum
ssc install fsum

*ftools
capture ado uninstall ftools // remove program if it existed previously
net install ftools, from("https://raw.githubusercontent.com/sergiocorreia/ftools/master/src/")

*reghdfe
capture ado uninstall reghdfe // remove program if it existed previously
net install reghdfe, from("https://raw.githubusercontent.com/sergiocorreia/reghdfe/master/src/")

*esttab
ssc install estout, replace
help esttab

*coefplot
ssc install coefplot, replace
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


*nr of panels
tab CityPair
di "nr of city pairs = " `r(r)'

tab YearMonth
di "nr of periods = " `r(r)'

tab Year
di "nr of years = " `r(r)'


*----------------
*declare panel
*----------------
egen k = group(CityPair)
egen t = group(YearMonth)
tsset k t


*----------------
*variables
*----------------
*extracting desired variables from the original dataset
keep k t price km_great_circle_distance jetfuel_price_org ///
	 nr_revenue_pax market_concentration_hhi pc_load_factor ///
	 YearMonth Year Month CityPair

*descriptive statistics
fsum, not(YearMonth k t) format(%10.2f)

*generating the transformed variables for the model
gen AirFare = ln(price)
gen Distance = ln(km_great_circle_distance)
gen FuelPrice = ln(jetfuel_price_org)
gen PaxDens = ln(nr_revenue_pax)
gen MktConc = ln(market_concentration_hhi*10000)
gen LoadFactor = ln(pc_load_factor)
gen Pandemic = (YearMonth>=202002 & YearMonth<=202204)
gen Trend = t/60

*descriptive statistics
fsum AirFare Distance FuelPrice PaxDens MktConc ///
	 LoadFactor Pandemic Trend

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

*fixed-effects without seasonality
reghdfe AirFare FuelPrice PaxDens MktConc LoadFactor ///
	Pandemic Trend ///
	, absorb(CityPair)

est store WithoutSeas

*fixed-effects with seasonality
reghdfe AirFare FuelPrice PaxDens MktConc LoadFactor ///
	Pandemic Trend ///
	WintBreak SummBrSearch SummBreak LowSeason ///
	, absorb(CityPair)

est store WithSeas

*show results table
esttab 	WithoutSeas WithSeas ///
		, nocons nose not nogaps noobs ///
		b(%9.4f) varwidth(14) brackets ///
		aic(%9.0fc) bic(%9.0fc) ar2 scalar(N) sfmt(%9.0fc) ///
		addnote("Notes: Fixed Effect estimation")


*-------------------------
*Experiment n. 2
*granular seasonality
*-------------------------
gen SummBreak_bef4 = (Month==8)
gen SummBreak_bef3 = (Month==9)
gen SummBreak_bef2 = (Month==10)
gen SummBreak_bef1 = (Month==11)
gen SummBreak_aft0 = (Month==12)
gen SummBreak_aft1 = (Month==1)
gen SummBreak_aft2 = (Month==2)
gen LowSeason_aft1 = (Month==4) // base case p0
gen LowSeason_aft2 = (Month==5)
gen LowSeason_aft3 = (Month==6)


*FE with seasonality
reghdfe AirFare FuelPrice PaxDens MktConc LoadFactor ///
	Pandemic Trend ///
	WintBreak SummBreak_* LowSeason_* ///
	, absorb(CityPair)

est store GranularSeas


*show results table
esttab 	GranularSeas ///
		, nocons nose not nogaps noobs ///
		b(%9.4f) varwidth(14) brackets ///
		aic(%9.0fc) bic(%9.0fc) ar2 scalar(N) sfmt(%9.0fc) ///
		addnote("Notes: Fixed Effect estimation")


*coefficient Plot
coefplot GranularSeas ///
		, keep(WintBreak SummBreak_* SummBreak_* LowSeason_*) ///
		xline(0, lcolor(green) lpattern(dash)) scheme(s2color) ///
		level(95) recast(connected) lpattern(longdash) lwidth(0.1)


*-------------------------
*Event study: pandemic
*-------------------------

*Before Pandemic
reghdfe AirFare FuelPrice PaxDens MktConc LoadFactor ///
	Trend WintBreak SummBreak_* LowSeason_* ///
	if YearMonth<=202001, absorb(CityPair)

est store PrePandemic

*Post Pandemic
reghdfe AirFare FuelPrice PaxDens MktConc LoadFactor ///
	Trend WintBreak SummBreak_* LowSeason_* ///
	if YearMonth>202204, absorb(CityPair)

est store PostPandemic

*show results table
esttab 	PrePandemic PostPandemic ///
		, nocons nose not nogaps noobs mtitles ///
		b(%9.4f) varwidth(14) brackets ///
		aic(%9.0fc) bic(%9.0fc) ar2 scalar(N) sfmt(%9.0fc) ///
		addnote("Notes: Dependent variable - AirFare" ///
		"Fixed Effect estimation")
		

*Coefficient Plot
coefplot PrePandemic PostPandemic ///
		, keep(WintBreak SummBreak_* SummBreak_* LowSeason_*) ///
		xline(0, lcolor(green) lpattern(dash)) scheme(s2color) ///
		level(95) recast(connected) lpattern(longdash) lwidth(0.1) 





