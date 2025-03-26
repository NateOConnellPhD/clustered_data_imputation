# Function to tabulate outcome metrics
# data: paramater defining data-frame of results
# summary_columns: vector of what measures to summarise
# condition: list with specified component vectors "type", "n_subj", and "miss_prob" defining which conditions to summarize

# Define the function
tab_metrics <- function(data, summary_columns, conditions = list(type = NULL, n_subj = NULL, miss_prob = NULL)) {
  
  # Filter data based on conditions (if any)
  if (!is.null(conditions$type)) {
    data <- data %>% filter(type %in% conditions$type)
  }
  if (!is.null(conditions$n_subj)) {
    data <- data %>% filter(n_subj %in% conditions$n_subj)
  }
  if (!is.null(conditions$miss_prob)) {
    data <- data %>% filter(miss_prob %in% conditions$miss_prob)
  }
  
  # Dynamically summarize the columns provided by summary_columns
  summary_table <- data %>%
    group_by(type, n_subj, miss_prob, method) %>%
    summarise(across(all_of(summary_columns), ~ sprintf("%.2f (%.2f)", mean(.x, na.rm = TRUE), sd(.x, na.rm = TRUE)))) %>%
    ungroup()
  
  # Arrange data by type, n_subj, miss_prob, and method
  summary_table <- summary_table %>% arrange(type, n_subj, miss_prob, method)
  
  # Get unique combinations and row indices for pack_rows
  combo_strings <- summary_table %>%
    distinct(type, n_subj, miss_prob) %>%
    mutate(
      type = ifelse(type == "bin", "Binary", "Continuous"),
      combo = paste0(type, ",  n=", n_subj, ", Missing Probability = ", miss_prob)
    ) %>%
    pull(combo)  # Extract the vector of descriptive strings
  
  # Calculate start and end indices for pack_rows
  dist <- seq(from = 1, to = length(unique(summary_table$method)) * length(combo_strings), by = length(unique(summary_table$method)))
  dist2 <- dist + length(unique(summary_table$method)) - 1
  
  # Initialize kable with basic structure
  kable_table <- summary_table %>%
    select(-type, -n_subj, -miss_prob) %>%
    kable("html", escape = FALSE, align = "c", col.names = c("Method", summary_columns)) %>%
    kable_styling(full_width = FALSE) 
    
  
  # Dynamically apply pack_rows in a loop with descriptive headers
  for (i in seq_along(combo_strings)) {
    kable_table <- kable_table %>% pack_rows(combo_strings[i], dist[i], dist2[i])
  }
  
  
  
  # Display the final table
  return(kable_table)
}
