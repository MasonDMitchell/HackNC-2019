
library(tidyverse)
library(rstan)

args = commandArgs(trailingOnly=TRUE);

rstan_options("auto_write" = TRUE);
options(mc.cores = parallel::detectCores());

unlink(file.path(".","results"),recursive=TRUE);
dir.create(file.path(".", "results"), showWarnings = FALSE);

predict_day_count <- 30;
person_id <- -1;
input_file <- "../clean_data/expd081.csv";
model_file <- "simple_categorical.stan";
training_person_count <- 10;

if (length(args) == 0){
  print("Usage: Rscript --vanilla test.R stan_file [input_file] [person_id] [training_data_size] [predict_day_count]")
  quit()
}

if (length(args) >= 1){
  model_file <- args[1];
}
if (model_file == "simple_categorical.stan") {
  training_person_count <- 2;
}
if (length(args) >= 2){
  input_file <- args[2];  
}
if(length(args) >= 3){
  person_id <- as.numeric(args[3]);
}
if(length(args) >= 4){
  training_person_count <- as.numeric(args[4]);
}
if(length(args) >= 5){
  predict_day_count <- as.numeric(args[5]);
}

data <- read_csv(input_file);
data <- data %>% 
	mutate(
	       date = ISOdate(year,month,day),
	       wday = weekdays(date),
	       week=factor(NEWID%%10),
	       USERID=factor(NEWID%/%10)) %>% 
	group_by(USERID,week) %>% 
	mutate(min_date = min(date), 
	       days_in = as.numeric(
		difftime(date,min_date,units="days"))) %>% 
	select(-year,-month,-day,-NEWID,-min_date) %>% 
	ungroup() %>%
	mutate(days_in = factor(days_in),
	       category = factor(category))

bad_ids <- data %>% 
	group_by(USERID,week,.drop=FALSE) %>% 
	summarize(sum = sum(COST)) %>% 
	summarize(min_count=min(sum)) %>% 
	filter(min_count == 0) %>% 
	pull(USERID)

data <- data %>% filter(!USERID %in% bad_ids)

model <- stan_model(model_file,
		    model_name="simple")

if (person_id == -1) {
  person_id <- (data %>% sample_n(1) %>% select(USERID))[[1]]
}

training_people_ids <- c(as.character(person_id),
			 as.character((
			   data %>% sample_n(training_person_count) %>% select(USERID))[["USERID"]]));

person_data <- data %>% filter(USERID %in% training_people_ids)
person_categories <- person_data %>% 
	filter(week == 1) %>% 
	select(category) %>% 
	unique() %>% 
	drop_na() %>%
	pull(category)
person_days <- person_data %>% 
	filter(week == 1) %>% 
	select(days_in) %>% 
	unique() %>% 
	drop_na() %>%
	pull(days_in);
print(person_days)

substrRight <- function(x, n){
  substr(x, nchar(x)-n+1, nchar(x))
}

cleaned_data <- list()
i <- 1
for (categ in person_categories){
  cat("Preparing category",format(as.numeric(categ)),"\n");
  category_data <- list();
  j <- 1
  for (person in training_people_ids) {
    cat_exp <- person_data %>%
	  filter(USERID == person) %>%
	  mutate(inter = interaction(category,week)) %>%
	  group_by(inter,days_in,.drop=FALSE) %>% 
	  summarize(sum=sum(COST),
		    category=first(na.omit(category)),
		    week=first(na.omit(week))) %>% 
	  mutate(category=first(na.omit(category)),
		 week=first(na.omit(week))) %>%
	  ungroup() %>% 
	  filter(category==categ,week==1) %>% 
	  pull(sum);

    cat_exp <- as.numeric(as.character(cat_exp));

    if (length(cat_exp) == 0){
      cat_exp <- rep(0.,length(person_days));
    }

    category_data[[j]] <- cat_exp;
    j <- j + 1;
  }
  cleaned_data[[i]] <- category_data;
  i <- i + 1;
}

cleaned_data_matrix <- do.call(rbind,cleaned_data);
cleaned_data <- array(unlist(cleaned_data),dim=c(dim(cleaned_data_matrix)[1],
					 dim(cleaned_data_matrix)[2],
					 length(person_days)));

sample <- sampling(model,
	     data=list(P=dim(cleaned_data)[2],
		       N=dim(cleaned_data)[3],
		       K=dim(cleaned_data)[1],
		       expenditure=cleaned_data,
		       predict_day_count=predict_day_count),
	     chains=1,
	     verbose=FALSE);

true_data <- list()
pre_data <- list()
i <- 1
j <- 1
for (categ in person_categories){
  cat_exp <- person_data %>%
	  filter(USERID == person_id) %>%
	  mutate(inter = interaction(category,week)) %>%
	  group_by(inter,days_in,.drop=FALSE) %>% 
	  summarize(sum=sum(COST),
		    category=first(na.omit(category)),
		    week=first(na.omit(week))) %>% 
	  mutate(category=first(na.omit(category)),
		 week=first(na.omit(week))) %>%
	  ungroup() %>% 
	  arrange(as.numeric(as.character(days_in))) %>%
	  filter(category==categ,week==2) %>% 
	  pull(sum);

  day=1;
  for (elem in as.numeric(cat_exp)){
    true_data[[i]] <- c(day=day, cat=categ, true=elem);
    i <- i + 1;
    day <- day + 1;
  }

  cat_exp <- person_data %>%
	  filter(USERID == person_id) %>%
	  mutate(inter = interaction(category,week)) %>%
	  group_by(inter,days_in,.drop=FALSE) %>% 
	  summarize(sum=sum(COST),
		    category=first(na.omit(category)),
		    week=first(na.omit(week))) %>% 
	  mutate(category=first(na.omit(category)),
		 week=first(na.omit(week))) %>%
	  ungroup() %>% 
	  arrange(as.numeric(as.character(days_in))) %>%
	  filter(category==categ,week==1) %>% 
	  pull(sum);
  day=1;
  for (elem in as.numeric(as.character(cat_exp))){
    pre_data[[j]] <- c(day=day, cat=categ, true=elem);
    j <- j + 1;
    day <- day + 1;
  }
}

true_data <- as.data.frame(do.call(rbind,true_data)) %>%
	mutate(true=as.numeric(as.character(true)));

true_data <- rbind(true_data, 
		   true_data %>% 
			   group_by(day) %>% 
			   summarize(true=sum(true)) %>% 
			   mutate(cat=as.factor(-1)));

pre_data <- as.data.frame(do.call(rbind,pre_data)) %>%
	mutate(true=as.numeric(as.character(true)));

pre_data <- rbind(pre_data, 
		   pre_data %>% 
			   group_by(day) %>% 
			   summarize(true=sum(true)) %>% 
			   mutate(cat=as.factor(-1)));

cumul_pre_data <- pre_data %>%
	group_by(cat) %>% 
	mutate(day=as.numeric(as.character(day))) %>%
	arrange(day) %>%
	mutate(true = cumsum(true))

max_exp_start <- max(unlist(cumul_pre_data %>% 
			select(true),
			use.names=FALSE))

write_csv(cumul_pre_data,"results/week_1_data.csv",append=FALSE,col_names=TRUE);

combins <- expand.grid(categ=1:dim(cleaned_data)[1],
		       person=c(1),
		       day=1:predict_day_count);
cumul_combins <- expand.grid(categ=1:dim(cleaned_data)[1],
		       person=c(1),
		       day=1:(predict_day_count+1));
per_day_combins <- expand.grid(person=c(1),
			       day=1:predict_day_count);
parameters_out <- c(sprintf("expen_predictions[%s,%s,%s]",
			    combins[["categ"]],
			    combins[["person"]],
			    combins[["day"]]),
		    sprintf("cumul_predictions[%s,%s,%s]",
			    cumul_combins[["categ"]],
			    cumul_combins[["person"]],
			    cumul_combins[["day"]]),
		    sprintf("total_prediction[%s,%s]",
			    per_day_combins[["person"]],
			    per_day_combins[["day"]]));


summary_data <- list();
summary_idx <- 1;
overall_result <- extract(sample,
			  pars=parameters_out,
			  permuted=TRUE);
for(par in parameters_out){
  result <- unlist(overall_result[par],
		   use.names=FALSE);
  pred_density <- density(result, n=512);

  out <- tibble(expenditure=pred_density$x+max_exp_start,density=pred_density$y) %>%
    filter(expenditure >= 0);

  x_max <- pred_density$x[which.max(pred_density$y)]
  quantiles <- quantile(result,c(0.05,0.95));


  if(startsWith(par,"expen")){

    idx <- strsplit(
	   gsub("[^0-9,]",
		"",
		sub("^[^/[]*", 
		    "", 
		    c(par))),
		",")[[1]]

    map_cat <- person_categories[as.numeric(idx[1])];

    #file_name <- sprintf("results/density_cat%s_day%s.csv",map_cat,idx[3]);
    #write_csv(out,file_name,append=FALSE,col_names=TRUE);

    summary_data[[summary_idx]] <- c(
				   day=as.character(idx[3]),
				   cat=as.character(map_cat),
				   low=quantiles[[1]],
				   mle=x_max,
				   high=quantiles[[2]],
				   cumul=FALSE);
    summary_idx <- summary_idx + 1;
  }
  else if (startsWith(par,"cumul")){
    idx <- strsplit(
           gsub("[^0-9,]",
                "",
                sub("^[^/[]*",
                    "",
                    c(par))),
                ",")[[1]]

    map_cat <- person_categories[as.numeric(idx[1])];

    file_name <- sprintf("results/density_cat%s_day%s.csv",map_cat,idx[3]);
    write_csv(out,file_name,append=FALSE,col_names=TRUE);

    summary_data[[summary_idx]] <- c(
                                   day=as.character(idx[3]),
                                   cat=as.character(map_cat),
                                   low=quantiles[[1]],
                                   mle=x_max,
                                   high=quantiles[[2]],
				   cumul=TRUE);
    summary_idx <- summary_idx + 1;
  }
  else {
    idx <- strsplit(
	   gsub("[^0-9,]",
		"",
		sub("^[^/[]*", 
		    "", 
		    c(par))),
		",")[[1]]

    file_name <- sprintf("results/density_total_day%s.csv",idx[2]);
    write_csv(out,file_name,append=FALSE,col_names=TRUE);

    summary_data[[summary_idx]] <- c(
				   day=as.character(idx[2]),
				   cat="-1",
				   low=quantiles[[1]],
				   mle=x_max,
				   high=quantiles[[2]],
				   cumul=FALSE);
    summary_idx <- summary_idx + 1;
  }
}

summary_frame <- as.data.frame(do.call(rbind,summary_data)) %>%
	mutate(low=as.numeric(as.character(low)),
	       mle=as.numeric(as.character(mle)),
	       high=as.numeric(as.character(high)));

summary_cumul <- summary_frame %>% filter(cumul==TRUE) %>% select(-cumul)
summary_frame <- summary_frame %>% filter(cumul==FALSE) %>% select(-cumul)

summary_cumul <- rbind(summary_cumul, 
		   summary_cumul %>% 
			   group_by(day) %>% 
			   summarize(low=sum(low),
				     mle=sum(mle),
				     high=sum(high)) %>% 
			   mutate(cat=as.factor(-1)));

summary_cumul <- summary_cumul %>%
	filter(as.numeric(as.character(day)) > 1) %>%
	mutate(day = as.numeric(as.character(day)) - 1) %>%
	mutate(low = low + max_exp_start,
	       mle = mle + max_exp_start,
	       high = high + max_exp_start)

cumul_true_data <- true_data %>%
	group_by(cat) %>% 
	mutate(day=as.numeric(as.character(day))) %>%
	arrange(day) %>%
	mutate(true = cumsum(true) + max_exp_start)

day_cat_compare <- full_join(true_data,summary_frame) %>% 
	mutate(true=ifelse(is.na(true),0,true),
	       low=ifelse(is.na(low),0,low),
	       mle=ifelse(is.na(mle),0,mle),
	       high=ifelse(is.na(high),0,high));

cumul_day_cat_compare <- full_join(cumul_true_data,summary_cumul) %>% 
	mutate(true=ifelse(is.na(true),0,true),
	       low=ifelse(is.na(low),0,low),
	       mle=ifelse(is.na(mle),0,mle),
	       high=ifelse(is.na(high),0,high));

#write_csv(day_cat_compare,"results/summary.csv",append=FALSE,col_names=TRUE);
write_csv(cumul_day_cat_compare,"results/summary.csv",append=FALSE,col_names=TRUE);

cat_compare <- day_cat_compare %>% 
	group_by(day) %>% 
	filter(!all(true==0)) %>% 
	ungroup() %>% 
	filter(cat!=-1) %>%
	group_by(cat) %>% 
	summarize(true=sum(true),
		  pred=sum(mle))

write_csv(cat_compare,"results/category_summary.csv",append=FALSE,col_names=TRUE);
