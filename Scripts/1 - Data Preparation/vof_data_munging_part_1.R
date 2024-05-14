# import the libraries
library(openxlsx)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)

# note: it was a long and complex process to prepare the open data for the analysis presented in the blog
# below, the high-level goals of the code are described. feel free to run various parts for a greater understanding
# all the analytical choices are spelled out here...


# https://drdoane.com/clean-consistent-column-names/
clean_names <- function(.data, unique = FALSE) {
  n <- if (is.data.frame(.data)) colnames(.data) else .data
  
  n <- gsub("%+", "_pct_", n)
  n <- gsub("\\$+", "_dollars_", n)
  n <- gsub("\\++", "_plus_", n)
  # removed, otherwise nis code gets a weird name
  # n <- gsub("-+", "_minus_", n)
  n <- gsub("\\*+", "_star_", n)
  n <- gsub("#+", "_cnt_", n)
  n <- gsub("&+", "_and_", n)
  n <- gsub("@+", "_at_", n)
  
  n <- gsub("[^a-zA-Z0-9_]+", "_", n)
  n <- gsub("([A-Z][a-z])", "_\\1", n)
  n <- tolower(trimws(n))
  
  n <- gsub("(^_+|_+$)", "", n)
  
  n <- gsub("_+", "_", n)
  
  if (unique) n <- make.unique(n, sep = "_")
  
  if (is.data.frame(.data)) {
    colnames(.data) <- n
    .data
  } else {
    n
  }
}

# define directories containing the raw data files and the place where we will save out the cleaned ones
# Note: change the directories to match the file structure on your system!
in_dir <- '~/Data Analysis Projects/Vibe of Flanders/Data/Raw/'
out_dir <- '~/Data Analysis Projects/Vibe of Flanders/Data/Derived/'

### Load meta data files, separate from the stadsmonitor data
### These help us add basic additional info and select data from the stadsmonitor data

# nis code file name
# from: https://statbel.fgov.be/sites/default/files/Over_Statbel_FR/Nomenclaturen/REFNIS_2019.csv
nis_code_file_name <- 'REFNIS_2019.csv'

# the survey data has results for overall provinces, while we want to just use the
# gemeenten as the level of analysis

# the NIS code data below will allow us to filter the survey data, only keeping
# the survey responses for the gemeenten, and removing province-level summaries

# nis code data
# read in csv from statbel with nis codes, and select only ones for towns/cities
nis_code_df <- read_csv2(paste0(in_dir, nis_code_file_name)) %>%
  clean_names() %>%
  # only select dutch column names
  select(code_nis, administratieve_eenheden, taal) %>%
  # remove the francophone, German speaking, and omnibus (e.g. per province/arrondissement) rows
  filter(taal == 'N') # %>% View()
# clean up
rm(nis_code_file_name)

# NIS code data will allow us to merge the province into the gemeente-level data 
# (province isn't included in the master survey data file provided by the govt)

# make mapping table to merge province into results in town-level dataframe
# https://nl.wikipedia.org/wiki/NIS-code
# De NIS-code bestaat uit 5 cijfers: Het eerste cijfer geeft de provincie aan; 
nis_first_digit <- c(1, 2, 3, 4, 7 )
province <- c('Antwerpen (Antwerp)', 'Vlaams-Brabant (Flemish Brabant)', 
              'West-Vlaanderen (West Flanders)', 
              'Oost-Vlaanderen (East Flanders)', 'Limburg (Limburg)')
nis_province_mapping_table <- as.data.frame(cbind(province, nis_first_digit))
# clean up
rm(nis_first_digit, province)


# Import the data from the source issued by the Flemish government
# one excel file with lots of sheets...

# master data file with survey data
master_file_name <- 'gemeentestadsmonitor_survey_alledata.xlsx'

# survey data
sheet_names <- getSheetNames(paste0(in_dir, master_file_name))
sheet_names[1:5]

# We will loop through each sheet, extract the data, and keep store it 
# temporarily in a list

# make a list to hold the data from each of the sheets
sheet_df_list <- list()

# the response options are inconsistently named in the file :( 
# we want to harmonize responses across sheets - the rename below helps us do this
# new column followed by old
# for fixing inconsistently named response options
lookup_rename <- c(eens_pct = "eens", hoog_pct = "hoog_8_of_meer_pct")

# loop through the sheets, extract the data and filter
for (i in 2:length(sheet_names)){
  print(i)
  print(sheet_names[i])
  sheet_name_loop <- sheet_names[i]
  sheet_loop <- read.xlsx(paste0(in_dir, master_file_name), 
                                         sheet = sheet_name_loop, 
                                         detectDates = T) %>%
    clean_names() %>% 
    # subset rows 
    # most recent results
    dplyr::filter(jaar == 2023,
                  # filter based on nis codes above
                  nis_code %in% nis_code_df$code_nis) %>%
    # add sheet name from excel as a column
    mutate(source_sheet = sheet_name_loop) %>%
    # not all columns with responses have the same names
    # e.g. "Eens" and  "Eens (%)" are the same and should
    # be placed together
    # rename them here
    rename(any_of(lookup_rename))

  # assign the loop data frame to our master list
  sheet_df_list[[i]] <- sheet_loop
  
  # clean up
  rm(sheet_name_loop)
  rm(sheet_loop)
  
}


# bind sheets together in one table
all_sheets_df <- dplyr::bind_rows(sheet_df_list) %>% 
  # trim whitespace for indicator and items
  mutate(indicator = str_trim(indicator),
         item = str_trim(item))

# clean up
rm(i, sheet_names, lookup_rename)

# how many indicators are there?
# 128
unique(all_sheets_df$indicator)

length(unique(all_sheets_df$indicator))
length(unique(all_sheets_df$gemeente))

unique(all_sheets_df$gemeente)

# this is the gemeente that's missing - in the nis code database, but not in the survey data?
# check of NIS code and gemeente name in survey data shows it's just not in there
nis_code_df %>% filter(!code_nis %in% unique(all_sheets_df$nis_code) ) # %>% dim()

# code_nis administratieve_eenheden taal 
# <chr>    <chr>                    <chr>
#   1 73028    Herstappe                N 


# for each possible answer set, we choose a single option

# identify which sheets have the same answer options
# we use this to make the subselection of answer items for each question
for (i in 1:length(sheet_df_list)){
  print(i)
  print(unique(sheet_df_list[[i]]$source_sheet))
  print(names(sheet_df_list[[i]]))
  print('*******')
}
# clean up
rm(sheet_df_list)


# we now have 1 row per gemeente / question, with the answer options in the columns
# lots of missing data - because each question only has a couple of options max
# we will need to select 1 answer option per question as a summary

# below, we make that selection per set of answer options
# we select below the answer option that indicates yes, positive responses, or agreement
# to be thematically consistent
head(all_sheets_df %>% tibble())
selected_columns <- all_sheets_df %>%
  # rename answer options for 
  # comfortably live
  mutate(het_lukt_om_rond_te_komen_top2 = (heel_erg_moeilijk_om_rond_te_komen_pct +  moeilijk_om_rond_te_komen_pct),
         frequentie_maandelijks_of_meer = (minstens_maandelijks_pct + minstens_wekelijks_pct)) %>%
  select(gemeente, nis_code, indicator, item, jaar, source_sheet, 
         het_lukt_om_rond_te_komen_top2, frequentie_maandelijks_of_meer,
         ja_pct, # and not nee_pct,
         # "nooit" appears consistently across multiple sheets
         # we will select it here and take the inverse below to get an indication of "not never"
         nooit_pct, # and not "12_keer_of_minder_pct", "meer_dan_12_keer_pct", "niet_aanwezig_in_mijn_gemeente_pct" or  "incidenteel_pct" "regelmatig_pct"
         tevreden_pct, # and not  "ontevreden_pct", "neutraal_pct"
         eens_pct, # and not "oneens_pct"   "neutraal_pct"
         de_gemeente_zet_hier_al_voldoende_op_in_pct, # and not de_gemeente_moet_hier_meer_op_inzetten_pct or de_gemeente_moet_hier_minder_op_inzetten_pct
         bereid_pct, # and not niet_bereid_pct, neutraal_pct
         veel_pct, # and not neutraal_pct or weinig_pct
         `2_dagen_of_meer_pct`, # and not minder_dan_2_dagen_pct
         vaak_altijd_pct, # and not "nooit_zelden_pct" "af_en_toe_pct" 
         # we will manually change below the question for transportation
         # here we select "auto" (car), and we will append this to the relevant
         # question below
         auto_pct, # king car, and not "te_voet_pct", "fiets_pct", "openbaar_vervoer_pct", "andere_pct" 
         lid_pct, # and not geen_lid_pct
         hoog_pct, # and not "laag_pct", "gemiddeld_pct"
         positief_pct, # and not "negatief_pct", "neutraal_pct" 
         sterk_pct, # and not "zwak_pct", "matig_pct" 
         meer_dan_10_pct, # and not "minder_dan_5_pct" "van_5_tot_10_pct" 
         vaak_altijd_pct, # and not "nooit_zelden_pct" "af_en_toe_pct" 
         meer_dan_30_pct_pct, # and not minder_of_gelijk_aan_30_pct_pct,
         ja_naar_een_andere_gemeente_stad_pct, # and not ja_binnen_dezelfde_gemeente_stad_pct" "nee_geen_verhuisplannen_pct"
         eigenaar_pct, # and not huurder_pct
         meer_dan_10_jaar_pct, #and not "5_jaar_of_minder_pct", "6_tot_en_met_10_jaar_pct"
         hinder_pct, # and not "geen_tot_weinig_hinder_pct", "beperkte_hinder_pct"   
         vaak_altijd_pct, # and not  "af_en_toe_pct", "nooit_zelden_pct" nooit_zelden_pct
         dagelijks_pct, # and not "nooit_minder_dan_1_keer_per_maand_pct", "meerdere_keren_per_maand_pct", "minstens_wekelijks_pct"  
         goed_pct )  %>% # and not  "slecht_pct"   "redelijk_pct")
         # 100 - nooit_pct to get inverse: "not never" 
         mutate(niet_nooit_pct = 100 - nooit_pct) %>%
         # remove the original "nooit_pct" column
         select(-nooit_pct) %>%
         # remove the items that are for other municipalities 
         filter(! grepl('Andere gemeente', item))# View()

table(selected_columns$item)

# / items
# pivot from long to wide
# merge in province

# the indicators and items are also translated into English (by Co-Pilot) 
# translation files 
item_trans_file_name <- 'item_mapping_table_en.xlsx'
indicator_trans_file_name <- 'indicator_translations.xlsx'

# we will eventually merge them in to have the possibility to 
# have the graphs in English

indicator_trans_df <- read.xlsx(paste0(in_dir, indicator_trans_file_name)) %>%
  # clean up some whitespace issues here
  mutate(indicator = str_trim(indicator),
         indicator_en = str_trim(indicator_en))

unique(selected_columns$indicator)

item_trans_df <- read.xlsx(paste0(in_dir, item_trans_file_name)) %>%
  # clean up some whitespace issues here
  mutate(item = str_trim(item),
         item_en = str_trim(item_en))

# join in English translations for indicator and item
trans_df <- selected_columns %>% dplyr::left_join(indicator_trans_df, by = 'indicator') %>%
  dplyr::left_join(item_trans_df, by = 'item') %>%
  # clean up some extra text in the indicator column
  mutate(indicator = gsub(' of andere', '', indicator),
         indicator_en = gsub(' or other', '', indicator_en)) %>%
  mutate(indicator = gsub(' \\(detail\\)', '', indicator),
         indicator_en = gsub(' \\(detail\\)', '', indicator_en)) %>%
  # replace accented characters with non accented characters
  mutate(indicator = stringi::stri_trans_general(indicator, "Latin-ASCII")) %>%
  # replace "per vervoermiddel" from indicator - helps with plotting
  mutate(indicator = gsub(": per vervoermiddel", '', indicator),
         indicator_en = gsub(': by mode of transport', '', indicator_en))


# missing data  
colMeans(is.na(trans_df))

# the question info is contained in two columns
# we first collapse the info into these two columns into one (omnibus_indicator)
# each row (gemeente / question) has response data in only one column
# we put the numeric responses into a single column,
# and then go from a long to wide data format.
# we put the gemeenten in the rows and the selected answer option data
# into the columns

# names(trans_df) %>% cat()
master_sm_df <- trans_df %>% 
  # merge in question subject
  # paste indicator and item to get all information about question
  mutate(omnibus_indicator = ifelse(is.na(item), indicator, paste(indicator, item, sep = ' - ')),
    # put numeric responses from all of the different answer options into a single column
    omnibus_response = coalesce(het_lukt_om_rond_te_komen_top2, frequentie_maandelijks_of_meer, 
                                ja_pct, tevreden_pct, eens_pct, de_gemeente_zet_hier_al_voldoende_op_in_pct, 
                                bereid_pct, veel_pct, `2_dagen_of_meer_pct`, vaak_altijd_pct, auto_pct, lid_pct, 
                                hoog_pct, positief_pct, sterk_pct, meer_dan_10_pct, meer_dan_30_pct_pct, 
                                ja_naar_een_andere_gemeente_stad_pct, eigenaar_pct, meer_dan_10_jaar_pct, 
                                hinder_pct, dagelijks_pct, goed_pct, niet_nooit_pct)) %>%   # View()
      # remove " - Eigen gemeente" from the end of omnibus_indicator columns
      mutate(omnibus_indicator = str_replace(omnibus_indicator, " - Eigen gemeente$", "")) %>%
      # select minimum columns needed (NL chosen here) 
      select(gemeente, nis_code,  omnibus_indicator, omnibus_response) %>%
      # pivot wider
      pivot_wider(names_from = omnibus_indicator, values_from = omnibus_response) %>% 
      # get info for first digit nis code to merge in province
      mutate(nis_first_digit = str_extract(nis_code, "^\\d{1}")) %>% 
      dplyr::right_join(nis_province_mapping_table, by = 'nis_first_digit') %>% 
      select(-nis_first_digit) %>% 
      relocate(province) %>% 
      # rename column about most frequently used transport - 
      # put "auto" directly in the column name
      # we selected this response option in the code above
      dplyr::rename('Verplaatsingen woon-werk/woon-school: dominant vervoermiddel - Auto' = "Verplaatsingen woon-werk/woon-school: dominant vervoermiddel" ) %>%
      # two questions () have answers that are decimals, not percentages. It appears that these should be percentages (the answer options sum to 1)
      # so this is a data error in the original export... check out the following sheets:
      # MO_S_22	Voldoende deelsystemen (auto, fiets,...)
      # MO_S_23	Voldoende autoluwe en autovrije zones
      # we correct this here:
      mutate(`Voldoende deelsystemen` = round(`Voldoende deelsystemen` * 100),
             `Voldoende autoluwe en autovrije zones` =   round(`Voldoende autoluwe en autovrije zones` * 100))
  

head(master_sm_df)

# check missing data - none!
names(master_sm_df)[colMeans(is.na(master_sm_df)) > 0]

# save out data file
saveRDS(master_sm_df, file = paste0(out_dir, "master_sm_df_20240506.RDS")) 

# codebook for analysis - mapping questions to subject matter
# this info will be used in the plots - for English translations and for 
# coding questions by subject

# English translations of the question subject, courtesy of co-pilot
# Create the dataframe
question_subject_translation_df <- data.frame(
  question_subject_nl = c("Armoede", "Cultuur en vrije tijd", "Demografie", "Klimaat, milieu en natuur", "Lokaal bestuur", "Mobiliteit", "Onderwijs en vorming", "Samenleven", "Werk", "Wonen en woonomgeving", "Zorg en gezondheid"),
  question_subject_en = c("Poverty", "Culture & leisure", "Demography", "Climate, environment & nature", "Local government", "Mobility", "Education & training", "Living together", "Work", "Living & living environment", "Care & health")
)

# the question subject is contained in the first sheet of the master data file
question_subject_df <- read.xlsx(paste0(in_dir, master_file_name),
                                 sheet = 1,
                                 detectDates = T) %>%
  dplyr::rename('question_subject_nl' = Thema,
                'source_sheet' = Tabblad,
                'indicator' = "Naam.indicator") %>%
  select(-indicator) %>%
  dplyr::left_join(question_subject_translation_df, by = 'question_subject_nl')

# we make a table where we link the question subjects to the survey questions
mapping_table_question_subject <- trans_df %>% 
  # merge in question subject
  dplyr::left_join(question_subject_df, by = 'source_sheet') %>% 
  mutate(omnibus_indicator = ifelse(is.na(item), indicator, paste(indicator, item, sep = ' - ')),
         omnibus_indicator_en = ifelse(is.na(item_en), indicator_en, paste(indicator_en, item_en, sep = ' - '))) %>%
  select(source_sheet, question_subject_nl, question_subject_en, 
         omnibus_indicator, omnibus_indicator_en)  %>%
  # remove " - Eigen gemeente" from the end of omnibus_indicator columns
  mutate(omnibus_indicator = str_replace(omnibus_indicator, " - Eigen gemeente$", ""),
         omnibus_indicator_en = str_replace(omnibus_indicator_en, " - Own municipality$", ""),
         question_subject_trans = paste0(question_subject_nl, ' (', question_subject_en, ')')) %>%
  distinct() %>%
  # rename item about most frequently used transport - 
  # to match the change made in the master dataset
  mutate(omnibus_indicator = recode(omnibus_indicator, 
                                    "Verplaatsingen woon-werk/woon-school: dominant vervoermiddel" = 'Verplaatsingen woon-werk/woon-school: dominant vervoermiddel - Auto'),
         omnibus_indicator_en = recode(omnibus_indicator_en, 
                                    "Commuting: dominant mode of transport" = 'Commuting: dominant mode of transport - Car'))


saveRDS(mapping_table_question_subject, file = paste0(out_dir, "mapping_table_question_subject_20240506.RDS")) 

