# Replication package for: A Real-Time Framework for Forecasting Metal Prices

This replication package accompanies Bastianin, Rossini and Tonni (2026). *A Real-Time Framework for Forecasting Metal Prices*


## Data availability and provenance statements.

### Statement about rights

The authors have legitimate access to all the data used in the paper. The data from LSEG and Consensus Economics are licensed and cannot be redistributed: the corresponding Excel files are included as empty templates that show the layout expected by the code. All other data are public and included.

### Summary of availability

| Data | Source | Included | Files |
|---|---|---|---|
| LME spot prices, inventories and futures (aluminum, copper, nickel, zinc) | LSEG | No (empty templates) | `ETM_daily.xlsx`, `futures_daily.xlsx` |
| S&P 500, gold, Baltic Dry Index, LME 3-month futures, stock price index by metal | LSEG Datastream | No (empty template) | `LSEG_2.xlsx` |
| Professional forecasts of metal prices | Consensus Economics | No (empty templates) | `EM<Mon><Year>.xlsx` (e.g. `EMApr2025.xlsx`), `p_forecasts_fixed_h_imputed.mat` |
| US predictors (Table 1), T10Y3M, VIX, WTI, DTB3, iron ore, exchange rates| ALFRED, St. Louis Fed | Yes | `data_FR.xlsx`, `example_revisions.xlsx`, `T10Y3M.xlsx`, `VIX.xlsx`, `WTI.xlsx`, `DTB3.xlsx`, `iron_ore_price.xlsx`, `AU.xlsx`, `CA.xlsx`, `CHN.xlsx`, `HK.xlsx`, `INDI.xlsx`, `INDO.xlsx`, `JP.xlsx`, `SF.xlsx`, `SW.xlsx`, `PH.csv`, `QA.csv`, `RO.csv`, `PREDICTORS_lev_*.mat`, `Results_nowcasting_*.mat` |
| OECD composite leading indicators, world industrial production | OECD; Baumeister and Hamilton (2019) | Yes | `CLI_vintages.csv`, `WIP_baumeister.xlsx` |

The data for Figure 1 (world consumption of the four metals) come from the World Bureau of Metal Statistics (WBMS); they are not public and are not included.

### Non-public data

The corresponding Excel files are included as empty templates that show the layout expected by the code.
Do not rename files or sheets and do not move the cells described below.

**LSEG: `Data/ETM_daily.xlsx` and `Data/futures_daily.xlsx`.** Daily LME cash prices (USD/t) and visible inventories (t), and daily LME futures (USD/t) at 3 and 15 months, for the four metals. Row 1 (headers) and column A (dates) are already in place; fill the other cells.
The code averages the daily values by calendar month. 
`ETM_daily.xlsx` must have no empty cells between the first and the last date.

`Data/Other Predictors/LSEG_2.xlsx`. Monthly series (December 1990 - May 2026), used only for Tables S.11-S.14. Each of the 11 sheets has a 6-row header (rows 1-3: start date, end date, frequency; row 4: name; row 5: Datastream code; row 6: currency) and dates in column A from row 7. Cell A1 holds the Datastream query (`=_xll.DSGRID(...)`): with the Datastream Excel add-in, recalculate it and paste the result **as values** from row 7.
The currency code in row 6 selects the exchange-rate file in `Data/Other Predictors/exchange_rates/` used to convert prices into USD.

**Consensus Economics: `Economic_Consensus/EM<Mon><Year>.xlsx`** (e.g. `EMApr2025.xlsx`). Each template has four empty sheets `Aluminium`, `Copper`, `Nickel`, `Zinc`. Copy each metal's sheet from the original survey workbook **keeping the original cell positions** (or replace the template with the original file). The code reads: `A4` survey date, `B7` spot price, `C5:F5` and `H5:K5` target dates, `C7:F7` and `H7:K7` consensus forecasts. 
Only the 98 surveys from April 2015 to October 2023 enter the results.

## Description of programs/code

- `economic_consensus_import.m`: reads the Consensus Economics files, converts fixed-event into fixed-horizon forecasts and saves the results in `Data/p_forecasts_fixed_h_imputed.mat`. Needs Consensus Economics data.
- `main_nowcast.m`: nowcasts the predictors (RW-D, AR, BAR, BAR-SV, BAR-SVo) and saves the real-time panels in `Data/`. Public data only.
- `main_forecast.m`: real-time forecasts, DM tests, MCS, pooling, DFM, financial predictors and figures; results are placed in the folder `outputs/`. Needs all non-public data.
- `Functions/`: contains all the functions used and recalled by the scripts above.

The code was tested with MATLAB R2025b and requires the Statistics and Machine Learning Toolbox.

## License for code

The code is licensed under a MIT license. See license.txt for details.

## List of tables and figures

Tables are printed in the Command Window; Figures are saved in `Figures/`.

| Output | Script | Where |
|---|---|---|
| Figure 2, Table 2 | `main_nowcast.m` | `Figures/example_revisions.pdf` and Command Window |
| Tables 3-4, Table 5 | `main_forecast.m` | Command Window |
| Figure 3 | `main_forecast.m` | `Figures/FAVAR_Copper_factors.pdf` |
| Figures 4-6; S.9-S.10 | `main_forecast.m` | `Figures/ratios_cum_<Metal>_<h>.pdf` (h = 6, 12, 18; 9, 15) |
| Figures S.1-S.8 | `main_forecast.m` | `Figures/ARDI_<Metal>{1,2}.pdf`, `Figures/FAVAR_<Metal>{1,2}.pdf` |
| Tables S.3-S.6 | `main_forecast.m` | `results_US_WORLD.tables_ratio_long_DM` in `outputs/results_ratio_US_WORLD.mat` |
| Tables S.7-S.8, S.9, S.11-S.14 | `main_forecast.m` | Command Window |
| Tables S.15-S.18 | `main_forecast.m` | `outputs/results_MCS.mat` (`table_export`) |

## Instructions to replicators

- Set the MATLAB working directory to the folder that contains the files.
- Public data only: run `main_nowcast.m` (Table 2, Figure 2). The `Data/*.mat` files it produces are already included.
- Full replication: fill the empty templates as described above, run `economic_consensus_import.m` and then `main_forecast.m`.

## Authors

- Andrea Bastianin
- Luca Rossini
- Lorenzo Tonni
