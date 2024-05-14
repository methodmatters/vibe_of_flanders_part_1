library(FactoMineR)
library(ggplot2)
library(dplyr)
library(ggrepel)
library(RColorBrewer)

# https://drdoane.com/clean-consistent-column-names/
clean_names <- function(.data, unique = FALSE) {
  n <- if (is.data.frame(.data)) colnames(.data) else .data

  n <- gsub("%+", "_pct_", n)
  n <- gsub("\\$+", "_dollars_", n)
  n <- gsub("\\++", "_plus_", n)
  n <- gsub("-+", "_minus_", n)
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

# plotting function - rectangle
myPng <- function(..., width=8, height=5, res=300) {
  png(..., width=width*res, height=height*res, res=res)
}

# plotting function - square
myPng_square <- function(..., width=8, height=8, res=300) {
  png(..., width=width*res, height=height*res, res=res)
}

# Note: change the directories to match the file structure on your system!
in_dir <- '~/Data Analysis Projects/Vibe of Flanders/Data/Derived/'
plot_dir <- "~/Data Analysis Projects/Vibe of Flanders/Plots/20240513/"
master_df <- readRDS(paste0(in_dir, "master_sm_df_20240506.RDS"))
question_mapping_table_df <- readRDS(paste0(in_dir, "mapping_table_question_subject_20240506.RDS"))


### FactoMiner for the PCA
### FactoMiner for the PCA
### FactoMiner for the PCA

# stadsmonitor pca
sm_pca = PCA(master_df[,c(1,4:ncol(master_df))], 
             scale.unit=TRUE, 
             quali.sup = 1,
             ncp=5, 
             graph=T)


# extract coordinates from the questions (variables)
# we will make a function to do this - otherwise, too complicated & too many intermediate objects

make_variable_coordinates <- function(pca_f, question_mapping_f){
  # extract the coordinates for the questions from the PCA results object
  item_coord_df_f <- as.data.frame(pca_f$var$coord) # %>%
  item_coord_df_f$omnibus_indicator <- row.names(item_coord_df_f)
  row.names(item_coord_df_f) <- NULL
  # merge in the question subjects and English translations
  item_coord_df_f <- item_coord_df_f %>% 
    dplyr::left_join(question_mapping_f, by = 'omnibus_indicator') %>%
    clean_names() 
  return(item_coord_df_f)
}

# make our variable coordinates object
vPCs <- make_variable_coordinates(sm_pca, question_mapping_table_df) 

str(vPCs)

# function to list the questions with the highest factor loadings on each PC
describe_top_questions <- function(vpcs_f, dim_f, thresh_pos_f, thresh_neg_f, num_name_pc_f){
  # from the vpcs object, select the question description in Dutch & English
  # along with the chosen dimension (PC)
   vpcs_select_f <- vpcs_f %>% select(omnibus_indicator, omnibus_indicator_en, round(all_of(dim_f), 2)) %>% 
  # filter any rows with PC loadings not greater than the absolute value of the chosen threshold
    filter((!!sym(dim_f)) > thresh_pos_f | (!!sym(dim_f)) < thresh_neg_f) %>%
  # sort the results by the loading 
    arrange(-(!!sym(dim_f))) %>% 
  # round to 2 decimal places
   mutate_if(is.numeric, round, 2)
  # make nice names to display in the table
  names(vpcs_select_f) <- c('Item - Dutch', 'Item - English', num_name_pc_f)
  return(vpcs_select_f)
}

# Dim 1
describe_top_questions(vpcs_f = vPCs, 
                       dim_f = 'dim_1', 
                       thresh_pos_f = .75, 
                       thresh_neg_f = -.6,
                       num_name_pc_f = 'PC 1')

# Dim 2
describe_top_questions(vpcs_f = vPCs, 
                       dim_f = 'dim_2', 
                       thresh_pos_f = .56, 
                       thresh_neg_f = -.5,
                       num_name_pc_f = 'PC 2') 

# # html tables used in blog
# library(knitr)
# # PC 1
# describe_top_questions(vpcs_f = vPCs, 
#                        dim_f = 'dim_1', 
#                        thresh_pos_f = .75, 
#                        thresh_neg_f = -.6,
#                        num_name_pc_f = 'PC 1') %>%
#   kable("html", align= 'c')
# 
# # PC 2
# describe_top_questions(vpcs_f = vPCs, 
#                        dim_f = 'dim_2', 
#                        thresh_pos_f = .56, 
#                        thresh_neg_f = -.5,
#                        num_name_pc_f = 'PC 2') %>%
#   kable("html", align= 'c')



# plot the eigenvalues from the PCA analysis
# not shown in blog post
sm_pca$eig %>% as.data.frame() %>% 
  mutate(comp = seq(1,nrow(.))) %>% # View()
  slice(1:10) %>%#  View()
  ggplot(aes(x = as.factor(comp), y = `eigenvalue`)) + 
  geom_bar(stat='identity',
           fill = "steelblue") +
  geom_hline(yintercept=1, linetype="dashed", color = "red") +
  labs(x = "Principal Component", 
       y = "Eigenvalue", 
       title = 'Scree Plot: First 10 Principal Components') 



### Plot the Questions in 2-dimensional space defined by the first 2 pcs
### Plot the Questions in 2-dimensional space defined by the first 2 pcs
### Plot the Questions in 2-dimensional space defined by the first 2 pcs
### Plot the Questions in 2-dimensional space defined by the first 2 pcs

# Create a custom color scale
display.brewer.all(n=NULL, type="all", select=NULL, exact.n=TRUE, 
                   colorblindFriendly=FALSE)
color_vector<-c('black','forestgreen', 'red2', 'orange', 'cornflowerblue',
                'mediumvioletred' , 'darkolivegreen4', 'indianred1', 'tan4', 'darkblue',
                'mediumorchid1','firebrick4',  'yellowgreen', 'lightsalmon', 'tan3',
                "tan1",'darkgray', 'wheat4', '#DDAD4B', 'chartreuse',
                'seagreen1', 'moccasin', 'magenta',  'seagreen','cadetblue1',
                "darkolivegreen1" ,"tan2" ,   "tomato3" , "#7CE3D8","gainsboro")
n_colors_question_themes <- length(levels(as.factor(vPCs$question_subject_trans)))
myColors_question_themes <- color_vector[1:n_colors_question_themes] # brewer.pal(n_colors_question_themes, "Paired")
names(myColors_question_themes) <- levels(as.factor(vPCs$question_subject_trans))
colScale_question_themes <- scale_colour_manual(name = "Question Topic", values = myColors_question_themes)


myPng_square(paste0(plot_dir, 'biplot_questions_points_20240513.png'))
vPCs %>% 
  # remove "Sociaal weefsel in de buurt - " at the beginning of the items, for plot
  mutate(omnibus_indicator = gsub("^Sociaal weefsel in de buurt - ", '', omnibus_indicator)) %>%
  filter(abs(dim_1) > .7 | abs(dim_2) > .5) %>% 
  ggplot(aes(x = dim_1, y = dim_2, color = question_subject_trans)) +
  # add faint lines at x and y of 0
  geom_hline(yintercept=0, color = "grey70", linewidth = .2) +
  geom_vline(xintercept=0, color = "grey70", linewidth = .2) +
  # define points based on x/y coordinates
  geom_point(show.legend = TRUE, 
             size = .5) +
  # add the text of the items to the graph
  geom_text_repel(max.overlaps = 15,
                  aes(x = dim_1, y = dim_2, color = question_subject_trans, label = omnibus_indicator),
                  cex= 2.7,
                  segment.size = .5,
                  segment.alpha = .2,
                  show.legend = FALSE,
                  # Strength of the repulsion force.
                  force = 2.5,
                  # Maximum iterations of the naive repulsion algorithm O(n^2).
                  max.iter = 20000,
                  ) +
  # add the x and y labels with % of variance explained with PCA
  xlab(paste0('PC 1 (', round(sm_pca$eig[1,2],1), '%)')) +
  ylab(paste0('PC 2 (', round(sm_pca$eig[2,2],1), '%)')) +
  theme_bw() +
  coord_cartesian(xlim = c(-1,1), ylim = c(-1,1)) +
  theme(legend.position="bottom", 
        legend.key=element_blank(), legend.key.size=unit(1,"point"),
        plot.subtitle=element_text(face="italic", size = 9),
        plot.caption=element_text(face="italic")) +
  # set up size of the points in legend
  # and number of columns for legend  
  guides(colour=guide_legend(ncol=2,
                             override.aes = list(size=1.3)))   +
  # guides(colour=guide_legend(ncol=2))   +
  # set up axis and legend labels
  labs(x = paste0('PC 1 (', round(sm_pca$eig[1,2],1), '%)'), 
       y = paste0('PC 2 (', round(sm_pca$eig[2,2],1), '%)'), 
       title = 'Plot of Survey Items on the First Two Themes / Principal Components' ,
       caption =  'Data: Stadsmonitor (2023)',
       color = "Question Topic") +
  colScale_question_themes
dev.off()


### Plot the province averages in the x/y space from the PCA
### Plot the province averages in the x/y space from the PCA
### Plot the province averages in the x/y space from the PCA
### Plot the province averages in the x/y space from the PCA
### Plot the province averages in the x/y space from the PCA

# functions to return the coordinates for gemeenten and provinces

# create the dataset for the gemeenten
make_gemeente_coordinates <- function(pca_f, master_df_f){
  PC1_f <- pca_f$ind$coord[,1]
  PC2_f <- pca_f$ind$coord[,2] 
  PC3_f <- pca_f$ind$coord[,3] 
  province_f <- as.character(master_df_f$province)
  gemeente_f <- as.character(master_df_f$gemeente)
  labs_f <- rownames(pca_f$ind$coord)  
  PCs_f <- data.frame(cbind(PC1_f, PC2_f, PC3_f, gemeente_f, province_f)) %>%
    mutate_at(vars(PC1_f, PC2_f, PC3_f), as.numeric)
  rownames(PCs_f) <- labs_f  
  colnames(PCs_f) <- c('PC1', 'PC2', 'PC3' , 'gemeente' , 'province') 
  return(PCs_f)
}

# make the gemeente coordinates
PCs <- make_gemeente_coordinates(sm_pca, master_df)
names(PCs)


str(PCs)

table(PCs$province)

# traditional statistical inference approach
# not shown in blog b/c who cares?

# PC1 - 2 choices as reference groups 
lm_province_wf_pc1 <- lm(PC1 ~ relevel(as.factor(province), ref = "West-Vlaanderen (West Flanders)") , data = PCs)
summary(lm_province_wf_pc1)
lm_province_vb_pc1 <- lm(PC1 ~ relevel(as.factor(province), ref = "Vlaams-Brabant (Flemish Brabant)") , data = PCs)
summary(lm_province_vb_pc1)
# PC2 - Antwerp is logical choice for ref grp
lm_province_ant_pc2 <- lm(PC2~ relevel(as.factor(province), ref = "Antwerpen (Antwerp)") , data = PCs)
summary(lm_province_ant_pc2)

# create the dataset for the provinces
make_province_coordinates <- function(pca_f){
  cPC1_f <- pca_f$quali.sup$coor[,1]  
  cPC2_f <- pca_f$quali.sup$coor[,2]  
  cPC3_f <- pca_f$quali.sup$coor[,3] 
  clabs_f <- rownames(pca_f$quali.sup$coor)  
  cPCs_f <- data.frame(cbind(cPC1_f, cPC2_f, cPC3_f, clabs_f)) %>%
    mutate_at(vars(cPC1_f, cPC2_f, cPC3_f), as.numeric)
  rownames(cPCs_f) <- clabs_f  
  colnames(cPCs_f) <- c('cPC1', 'cPC2', 'cPC3' , 'province')  
  
  return(cPCs_f)
}

# make province coordinates
cPCs <- make_province_coordinates(sm_pca)

#### Omnibus plot of gemeenten and provinces in the 2-dimensional space defined by pcs 1 & 2
#### Omnibus plot of gemeenten and provinces in the 2-dimensional space defined by pcs 1 & 2
#### Omnibus plot of gemeenten and provinces in the 2-dimensional space defined by pcs 1 & 2
#### Omnibus plot of gemeenten and provinces in the 2-dimensional space defined by pcs 1 & 2
#### Omnibus plot of gemeenten and provinces in the 2-dimensional space defined by pcs 1 & 2


library(RColorBrewer)
n_colors_provinces <- length(levels(as.factor(PCs$province)))
myColors_provinces <- brewer.pal(n_colors_provinces, "Set1")
names(myColors_provinces) <- levels(as.factor(PCs$province))
colScale_province <- scale_colour_manual(name = "Province", values = myColors_provinces)

# one plot to rule them all
myPng_square(paste0(plot_dir, 'biplot_omnibus_municp_provs_20240513.png'))
ggplot(PCs, aes(x = PC1, y = PC2, color = province)) + 
  geom_point()  +
  # define the colors, axis limits & labels  
  coord_cartesian(xlim = c(-5, 5), ylim = c(-5, 5))  +
  geom_hline(yintercept=0, color = "black", linewidth = .2) +
  geom_vline(xintercept=0, color = "black", linewidth = .2) +
  labs(x = paste0('PC 1 (', round(sm_pca$eig[1,2],1), '%)'), 
       y = paste0('PC 2 (', round(sm_pca$eig[2,2],1), '%)'), 
       title = 'Plot of Gemeenten / Municipalities and Province Averages on the First Two Themes' ,
       subtitle = 'Small Points: Gemeenten / Municipalities, Large Points: Province Averages',
       caption = 'Data: Stadsmonitor (2023)',
       color = "Province") +
  # add the average of each province as a separate, larger point 
  geom_point(data = cPCs, 
                    aes(x=cPC1, 
                        y=cPC2), 
                    size = 8) + 
  # high dim 1
  annotate(geom = 'label', x = 4.7, y = 0,
           label = 'Feel Good \n Where They Live',
           color = 'darkblue', size = 3) + 
  # low dim 1
  annotate(geom = 'label', x = -4.7, y = 0,
           label = 'Feel Unsafe \n Where They Live',
           color = 'darkblue', size = 3) + 
  # high dim 2
  annotate(geom = 'label', x = 0, y = 5.12,
           label = 'Use Environmentally \n Sustainable Transport',
           color = 'darkblue', size = 3) + 
  # low dim 2
  annotate(geom = 'label', x = 0, y = -5.12,
         label = 'Reliant on \n the Car',
         color = 'darkblue', size = 3) + 
  theme_bw() +
  theme(legend.position="bottom", 
        legend.key=element_blank(), legend.key.size=unit(1,"point"),
        plot.subtitle=element_text(face="italic", size = 9),
        plot.caption=element_text(face="italic")) +
  guides(colour=guide_legend(ncol=3))  +
  colScale_province
dev.off()


### Quadrant Analysis: Plotting the Extremes for both ends of pc 1 & 2
### Quadrant Analysis: Plotting the Extremes for both ends of pc 1 & 2
### Quadrant Analysis: Plotting the Extremes for both ends of pc 1 & 2
### Quadrant Analysis: Plotting the Extremes for both ends of pc 1 & 2
### Quadrant Analysis: Plotting the Extremes for both ends of pc 1 & 2


# Lowest on PC 1
myPng(paste0(plot_dir, 'biplot_lowest_pc1_20240513.png'))
PCs %>%
  ggplot(aes(x = PC1, y = PC2, color = province)) + 
  geom_point(size = .8)  +
  xlim(c(min(PCs$PC1), mean(PCs$PC1) - 2 * sd(PCs$PC1)))  + 
  geom_text_repel(max.overlaps = 15, 
                  aes(x = PC1, y = PC2, color = province, label = gemeente),
                  cex= 3,
                  segment.size = .5,
                  segment.alpha = .2,
                  # Strength of the repulsion force.
                  force = 2.5,
                  # Maximum iterations of the naive repulsion algorithm O(n^2).
                  max.iter = 20000,
                  show.legend = FALSE) +
  labs(x = paste0('PC 1 (', round(sm_pca$eig[1,2],1), '%)'), 
       y = paste0('PC 2 (', round(sm_pca$eig[2,2],1), '%)'), 
       title = 'Gemeenten / Municipalities Scoring Lowest on Theme / Principal Component 1' ,
       subtitle = 'Residents of These Gemeenten / Municipalities Report Feeling Unsafe',
       caption = 'Data: Stadsmonitor (2023)',
       color = "Province") + 
  theme_bw()  +
  theme(plot.subtitle=element_text(face="italic", size = 9),
        plot.caption=element_text(face="italic")) +
  guides(colour = guide_legend(override.aes = list(size=2))) +
  annotate(geom = 'label', x = -23.45, y = 19.9,
                        label = 'Feel Unsafe \n Where They Live',
                        color = 'darkblue', size = 3)  +
  colScale_province
dev.off()

# Highest on PC 1
myPng(paste0(plot_dir, 'biplot_highest_pc1_20240513.png'))
PCs %>%
  ggplot(aes(x = PC1, y = PC2, color = province)) + 
  geom_point(size = .8)  +
  xlim(c(mean(PCs$PC1) + 1 * sd(PCs$PC1)), max(PCs$PC1)) + 
  ylim(c(-10,15)) +
  geom_text_repel(max.overlaps = 15, 
                  aes(x = PC1, y = PC2, color = province, label = gemeente),
                  cex= 3,
                  segment.size = .5,
                  segment.alpha = .2,
                  # Strength of the repulsion force.
                  force = 2.5,
                  # Maximum iterations of the naive repulsion algorithm O(n^2).
                  max.iter = 20000,
                  show.legend = FALSE) +
  labs(x = paste0('PC 1 (', round(sm_pca$eig[1,2],1), '%)'), 
       y = paste0('PC 2 (', round(sm_pca$eig[2,2],1), '%)'), 
       title = 'Gemeenten / Municipalities Scoring Highest on Theme / Principal Component 1' ,
       subtitle = 'Residents Have Positive Feelings About Where They Live',
       caption = 'Data: Stadsmonitor (2023)',
       color = "Province") +
  theme_bw()  +
  theme(plot.subtitle=element_text(face="italic", size = 9),
        plot.caption=element_text(face="italic")) +
  guides(colour = guide_legend(override.aes = list(size=2))) +
  annotate(geom = 'label', x = 10.21, y = 14.7,
           label = 'Feel Good \n Where They Live',
           color = 'darkblue', size = 3)  +
  colScale_province
dev.off()
  
######

# Lowest on PC 2
myPng(paste0(plot_dir, 'biplot_lowest_pc2_20240513.png'))
PCs %>%
  ggplot(aes(x = PC1, y = PC2, color = province)) + 
  geom_point(size = .8)  +
  # define the colors, axis limits & labels  
  ylim(c(min(PCs$PC2), -5)) + 
  geom_text_repel(max.overlaps = 15, 
                  aes(x = PC1, y = PC2, color = province, label = gemeente),
                  cex= 3,
                  segment.size = .5,
                  segment.alpha = .2,
                  # Strength of the repulsion force.
                  force = 2.5,
                  # Maximum iterations of the naive repulsion algorithm O(n^2).
                  max.iter = 20000,
                  show.legend = FALSE) +
  labs(x = paste0('PC 1 (', round(sm_pca$eig[1,2],1), '%)'), 
       y = paste0('PC 2 (', round(sm_pca$eig[2,2],1), '%)'), 
       title = 'Gemeenten / Municipalities Scoring Lowest on Theme / Principal Component 2' ,
       subtitle = 'Residents Are Reliant On the Car',
       caption = 'Data: Stadsmonitor (2023)',
       color = "Province")  +
  theme_bw()  +
  theme(plot.subtitle=element_text(face="italic", size = 9),
        plot.caption=element_text(face="italic")) +
  guides(colour = guide_legend(override.aes = list(size=2))) +
  annotate(geom = 'label', x = -22.4, y = -10.55,
           label = 'Reliant on \n the Car', 
           color = 'darkblue', size = 3)  +
  colScale_province
dev.off()

# Highest on PC 2
myPng(paste0(plot_dir, 'biplot_highest_pc2_20240513.png'))
PCs %>%
  ggplot(aes(x = PC1, y = PC2, color = province)) + 
  geom_point(size = .8)  +
  # define the colors, axis limits & labels  
  ylim(c(mean(PCs$PC2) + 1 * sd(PCs$PC2)), max(PCs$PC2)) + 
  geom_text_repel(max.overlaps = 15, 
                  aes(x = PC1, y = PC2, color = province, label = gemeente),
                  cex= 2,
                  segment.size = .5,
                  segment.alpha = .2,
                  # Strength of the repulsion force.
                  force = 2.5,
                  # Maximum iterations of the naive repulsion algorithm O(n^2).
                  max.iter = 20000,
                  show.legend = FALSE) +
  labs(x = paste0('PC 1 (', round(sm_pca$eig[1,2],1), '%)'), 
       y = paste0('PC 2 (', round(sm_pca$eig[2,2],1), '%)'), 
       title = 'Gemeenten / Municipalities Scoring Highest on Theme / Principal Component 2' ,
       subtitle = 'Residents Use Environmentally Sustainable Transport',
       caption = 'Data: Stadsmonitor (2023)', 
       color = "Province") +  
  theme_bw()  +
  theme(plot.subtitle=element_text(face="italic", size = 9),
        plot.caption=element_text(face="italic")) +
  guides(colour = guide_legend(override.aes = list(size=2))) +
  annotate(geom = 'label', x = -20.75, y = 20,
           label = 'Use Environmentally \n Sustainable Transport',
           color = 'darkblue', size = 3)  +
  colScale_province
dev.off()

