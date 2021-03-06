context("binds")


# base --------------------------------------------------------------------

test_that("cbind and rbind methods work for tbl_df", {
  df1 <- tibble(x = 1)
  df2 <- tibble(y = 2)

  expect_equal(cbind(df1, df2), tibble(x = 1, y = 2))
  expect_equal(rbind(df1, df2), tibble(x = c(1, NA), y = c(NA, 2)))
})


# error -------------------------------------------------------------------

test_that("bind_rows() and bind_cols() err for non-data frames (#2373)", {
  df1 <- memdb_frame(x = 1)
  df2 <- memdb_frame(y = 2)

  expect_error(
    bind_cols(df1, df2),
    "Data-frame-like objects must inherit from class data.frame or be plain lists"
  )
  expect_error(
    bind_rows(df1, df2),
    "Data-frame-like objects must inherit from class data.frame or be plain lists"
  )
})


# columns -----------------------------------------------------------------

test_that("cbind uses shallow copies", {
  df1 <- data.frame(
    int = 1:10,
    num = rnorm(10),
    cha = letters[1:10],
    stringsAsFactors = FALSE)
  df2 <- data.frame(
    log = sample(c(T, F), 10, replace = TRUE),
    dat = seq.Date(Sys.Date(), length.out = 10, by = "day"),
    tim = seq(Sys.time(), length.out = 10, by = "1 hour")
  )
  df <- bind_cols(df1, df2)

  expect_equal(dfloc(df1), dfloc(df)[names(df1)])
  expect_equal(dfloc(df2), dfloc(df)[names(df2)])
})

test_that("bind_cols handles lists (#1104)", {
  exp <- data_frame(x = 1, y = "a", z = 2)

  l1 <- list(x = 1, y = "a")
  l2 <- list(z = 2)

  expect_equal(bind_cols(l1, l2), exp)
  expect_equal(bind_cols(list(l1, l2)), exp)
})

test_that("bind_cols handles empty argument list (#1963)", {
  expect_equal(bind_cols(), data.frame())
})

test_that("bind_cols handles all-NULL values (#2303)", {
  expect_equal(bind_cols(list(a = NULL, b = NULL)), data.frame())
})

test_that("bind_cols repairs names", {
  df <- tibble(a = 1, b = 2)
  bound <- bind_cols(df, df)

  repaired <- as_tibble(tibble::repair_names(
    data.frame(a = 1, b = 2, a = 1, b = 2, check.names = FALSE)
  ))

  expect_equal(bound, repaired)
})

# rows --------------------------------------------------------------------

df_var <- data_frame(
  l = c(T, F, F),
  i = c(1, 1, 2),
  d = Sys.Date() + c(1, 1, 2),
  f = factor(letters[c(1, 1, 2)]),
  n = c(1, 1, 2) + 0.5,
  t = Sys.time() + c(1, 1, 2),
  c = letters[c(1, 1, 2)]
)

test_that("bind_rows() equivalent to rbind()", {
  exp <- tbl_df(rbind(df_var, df_var, df_var))
  expect_equal(bind_rows(df_var, df_var, df_var), exp)
  expect_equal(bind_rows(list(df_var, df_var, df_var)), exp)
})

test_that("bind_rows reorders columns", {
  df_var_scramble <- df_var[sample(ncol(df_var))]

  expect_equal(
    names(bind_rows(df_var, df_var_scramble)),
    names(df_var)
  )
})

test_that("bind_rows ignores NULL", {
  df <- data_frame(a = 1)

  expect_equal(bind_rows(df, NULL), df)
  expect_equal(bind_rows(list(df, NULL)), df)
})

test_that("bind_rows only accepts data frames #288", {
  ll <- list(1:5, 6:10)
  expect_error(bind_rows(ll), "cannot convert")
})

test_that("bind_rows handles list columns (#463)", {
  dfl <- data_frame(x = I(list(1:2, 1:3, 1:4)))
  res <- bind_rows(list(dfl, dfl))
  expect_equal(rep(dfl$x, 2L), res$x)
})

test_that("can bind lists of data frames #1389", {
  df <- data_frame(x = 1)

  res <- bind_rows(list(df, df), list(df, df))
  expect_equal(nrow(res), 4)
})

test_that("bind_rows handles data frames with no rows (#597)", {
  df1 <- data_frame(x = 1, y = factor("a"))
  df0 <- df1[0, ]

  expect_equal(bind_rows(df0), df0)
  expect_equal(bind_rows(df0, df0), df0)
  expect_equal(bind_rows(df0, df1), df1)
})

test_that("bind_rows handles data frames with no columns (#1346)", {
  df1 <- data_frame(x = 1, y = factor("a"))
  df0 <- df1[, 0]

  expect_equal(bind_rows(df0), df0)
  expect_equal(dim(bind_rows(df0, df0)), c(2, 0))

  res <- bind_rows(df0, df1)
  expect_equal(res$x, c(NA, 1))
})

test_that("bind_rows handles lists with NULL values (#2056)", {
  df1 <- data_frame(x = 1, y = 1)
  df2 <- data_frame(x = 2, y = 2)
  lst1 <- list(a = df1, NULL, b = df2)

  df3 <- data_frame(
    names = c("a", "b"),
    x = c(1, 2),
    y = c(1, 2)
  )

  expect_equal(bind_rows(lst1, .id = "names"), df3)
})

test_that("bind_rows puts data frames in order received even if no columns (#2175)", {
  df2 <- data_frame(x = 2, y = "b")
  df1 <- df2[, 0]

  res <- bind_rows(df1, df2)

  expect_equal(res$x, c(NA, 2))
  expect_equal(res$y, c(NA, "b"))
})

# Column coercion --------------------------------------------------------------

test_that("bind_rows promotes integer to numeric", {
  df1 <- data_frame(a = 1L, b = 1L)
  df2 <- data_frame(a = 1, b = 1L)

  res <- bind_rows(df1, df2)
  expect_equal(typeof(res$a), "double")
  expect_equal(typeof(res$b), "integer")
})

test_that("bind_rows does not coerce logical to integer", {
  df1 <- data_frame(a = FALSE)
  df2 <- data_frame(a = 1L)

  expect_error(bind_rows(df1, df2),
               "Can not automatically convert from logical to integer in column \"a\"")
})

test_that("bind_rows promotes factor to character with warning", {
  df1 <- data_frame(a = factor("a"))
  df2 <- data_frame(a = "b")

  expect_warning(
    res <- bind_rows(df1, df2),
    "binding factor and character vector, coercing into character vector"
  )
  expect_equal(typeof(res$a), "character")
})

test_that("bind_rows coerces factor to character when levels don't match", {
  df1 <- data.frame(a = factor("a"))
  df2 <- data.frame(a = factor("b"))

  expect_warning(
    res <- bind_rows(df1, df2),
    "Unequal factor levels: coercing to character"
  )
  expect_equal(res$a, c("a", "b"))
})

test_that("bind_rows handles NA in factors #279", {
  df1 <- data_frame(a = factor("a"))
  df2 <- data_frame(a = factor(NA))

  expect_warning(res <- bind_rows(df1, df2), "Unequal factor levels")
  expect_equal(res$a, c("a", NA))
})

test_that("bind_rows doesn't promote integer/numeric to factor", {
  df1 <- data_frame(a = factor("a"))
  df2 <- data_frame(a = 1L)
  df3 <- data_frame(a = 1)

  expect_error(bind_rows(df1, df2), "from factor to integer")
  expect_error(bind_rows(df1, df3), "from factor to numeric")
})


test_that("bind_rows preserves timezones #298", {
  dates1 <- data.frame(ID = c("a", "b", "c"),
    dates = structure(c(-247320000, -246196800, -245073600),
      tzone = "GMT",
      class = c("POSIXct", "POSIXt")),
    stringsAsFactors = FALSE)

  dates2 <- data.frame(ID = c("d", "e", "f"),
    dates = structure(c(-243864000, -242654400, -241444800),
      tzone = "GMT",
      class = c("POSIXct", "POSIXt")),
    stringsAsFactors = FALSE)

  alldates <- bind_rows(dates1, dates2)
  expect_equal(attr(alldates$dates, "tzone"), "GMT")
})

test_that("bind_rows handles all NA columns (#493)", {
  mydata <- list(
    data.frame(x = c("foo", "bar")),
    data.frame(x = NA)
  )
  res <- bind_rows(mydata)
  expect_true(is.na(res$x[3]))
  expect_is(res$x, "factor")

  mydata <- list(
    data.frame(x = NA),
    data.frame(x = c("foo", "bar"))
  )
  res <- bind_rows(mydata)
  expect_true(is.na(res$x[1]))
  expect_is(res$x, "factor")

})

test_that("bind_rows handles complex. #933", {
  df1 <- data.frame(r = c(1 + 1i, 2 - 1i))
  df2 <- data.frame(r = c(1 - 1i, 2 + 1i))
  df3 <- bind_rows(df1, df2)
  expect_equal(nrow(df3), 4L)
  expect_equal(df3$r, c(df1$r, df2$r))
})

test_that("bind_rows is careful about column names encoding #1265", {
  one <- data.frame(foo = 1:3, bar = 1:3)
  names(one) <- c("f\u00fc", "bar")
  two <- data.frame(foo = 1:3, bar = 1:3)
  names(two) <- c("f\u00fc", "bar")
  Encoding(names(one)[1]) <- "UTF-8"
  expect_equal(names(one), names(two))
  res <- bind_rows(one, two)
  expect_equal(ncol(res), 2L)
})

test_that("bind_rows handles POSIXct (#1125)", {
  df1 <- data.frame(date = as.POSIXct(NA))
  df2 <- data.frame(date = as.POSIXct("2015-05-05"))
  res <- bind_rows(df1, df2)
  expect_equal(nrow(res), 2L)
  expect_true(is.na(res$date[1]))
})

test_that("bind_rows respects ordered factors (#1112)", {
  l <- c("a", "b", "c", "d")
  id <- factor(c("a", "c", "d"), levels = l, ordered = TRUE)
  df <- data.frame(id = rep(id, 2), val = rnorm(6))
  res <- bind_rows(df, df)
  expect_is(res$id, "ordered")
  expect_equal(levels(df$id), levels(res$id))

  res <- group_by(df, id) %>% do(na.omit(.))
  expect_is(res$id, "ordered")
  expect_equal(levels(df$id), levels(res$id))
})

test_that("bind_rows can handle lists (#1104)", {
  my_list <- list(list(x = 1, y = "a"), list(x = 2, y = "b"))
  res <- bind_rows(my_list)
  expect_equal(nrow(res), 2L)
  expect_is(res$x, "numeric")
  expect_is(res$y, "character")

  res <- bind_rows(list(x = 1, y = "a"), list(x = 2, y = "b"))
  expect_equal(nrow(res), 2L)
  expect_is(res$x, "numeric")
  expect_is(res$y, "character")
})

test_that("bind_rows keeps ordered factors (#948)", {
  y <- bind_rows(
    data.frame(x = factor(c(1, 2, 3), ordered = TRUE)),
    data.frame(x = factor(c(1, 2, 3), ordered = TRUE))
  )
  expect_is(y$x, "ordered")
  expect_equal(levels(y$x), as.character(1:3))
})

test_that("bind handles POSIXct of different tz ", {
  date1 <- structure(-1735660800, tzone = "America/Chicago", class = c("POSIXct", "POSIXt"))
  date2 <- structure(-1735660800, tzone = "UTC", class = c("POSIXct", "POSIXt"))
  date3 <- structure(-1735660800, class = c("POSIXct", "POSIXt"))

  df1 <- data.frame(date = date1)
  df2 <- data.frame(date = date2)
  df3 <- data.frame(date = date3)

  res <- bind_rows(df1, df2)
  expect_equal(attr(res$date, "tzone"), "UTC")

  res <- bind_rows(df1, df3)
  expect_equal(attr(res$date, "tzone"), "America/Chicago")

  res <- bind_rows(df2, df3)
  expect_equal(attr(res$date, "tzone"), "UTC")

  res <- bind_rows(df3, df3)
  expect_equal(attr(res$date, "tzone"), NULL)

  res <- bind_rows(df1, df2, df3)
  expect_equal(attr(res$date, "tzone"), "UTC")

})

test_that("bind_rows() creates a column of identifiers (#1337)", {
  data1 <- mtcars[c(2, 3), ]
  data2 <- mtcars[1, ]

  out <- bind_rows(data1, data2, .id = "col")
  out_list <- bind_rows(list(data1, data2), .id = "col")
  expect_equal(names(out)[1], "col")
  expect_equal(out$col, c("1", "1", "2"))
  expect_equal(out_list$col, c("1", "1", "2"))

  out_labelled <- bind_rows(one = data1, two = data2, .id = "col")
  out_list_labelled <- bind_rows(list(one = data1, two = data2), .id = "col")
  expect_equal(out_labelled$col, c("one", "one", "two"))
  expect_equal(out_list_labelled$col, c("one", "one", "two"))
})


test_that("string vectors are filled with NA not blanks before collection (#595)", {
  one <- mtcars[1:10, -10]
  two <- mtcars[11:32, ]
  two$char_col <- letters[1:22]

  res <- bind_rows(one, two)
  expect_true(all(is.na(res$char_col[1:10])))
})

test_that("bind_rows handles POSIXct stored as integer (#1402)", {
  now <- Sys.time()

  df1 <- data.frame(time = now)
  expect_equal(class(bind_rows(df1)$time), c("POSIXct", "POSIXt"))

  df2 <- data.frame(time = seq(now, length.out = 1, by = 1))
  expect_equal(class(bind_rows(df2)$time), c("POSIXct", "POSIXt"))

  res <- bind_rows(df1, df2)
  expect_equal(class(res$time), c("POSIXct", "POSIXt"))
  expect_true(all(res$time == c(df1$time, df2$time)))
})

test_that("bind_cols accepts NULL (#1148)", {
  df1 <- data_frame(a = 1:10, b = 1:10)
  df2 <- data_frame(c = 1:10, d = 1:10)

  res1 <- bind_cols(df1, df2)
  res2 <- bind_cols(NULL, df1, df2)
  res3 <- bind_cols(df1, NULL, df2)
  res4 <- bind_cols(df1, df2, NULL)

  expect_equal(res1, res2)
  expect_equal(res1, res3)
  expect_equal(res1, res4)
})

test_that("bind_rows handles 0-length named list (#1515)", {
  res <- bind_rows(list(a = 1)[-1])
  expect_equal(nrow(res), 0L)
  expect_is(res, "data.frame")
  expect_equal(ncol(res), 0L)
})

test_that("bind_rows handles promotion to strings (#1538)", {
  df1 <- data_frame(b = c(1, 2))
  df2 <- data_frame(b = c(1L, 2L))
  df3 <- data_frame(b = factor(c("A", "B")))
  df4 <- data_frame(b = c("C", "D"))

  expect_error(bind_rows(df1, df3))
  expect_error(bind_rows(df1, df4))
  expect_error(bind_rows(df2, df3))
  expect_error(bind_rows(df2, df4))
})

test_that("bind_rows infers classes from first result (#1692)", {
  d1 <- data.frame(a = 1:10, b = rep(1:2, each = 5))
  d2 <- tbl_df(d1)
  d3 <- group_by(d1, b)
  d4 <- rowwise(d1)
  d5 <- list(a = 1:10, b = rep(1:2, each = 5))

  expect_equal(class(bind_rows(d1, d1)), "data.frame")
  expect_equal(class(bind_rows(d2, d1)), c("tbl_df", "tbl", "data.frame"))
  res3 <- bind_rows(d3, d1)
  expect_equal(class(res3), c("grouped_df", "tbl_df", "tbl", "data.frame"))
  expect_equal(attr(res3, "group_sizes"), c(10, 10))
  expect_equal(class(bind_rows(d4, d1)), c("rowwise_df", "tbl_df", "tbl", "data.frame"))
  expect_equal(class(bind_rows(d5, d1)), c("tbl_df", "tbl", "data.frame"))

})

test_that("bind_cols infers classes from first result (#1692)", {
  d1 <- data.frame(a = 1:10, b = rep(1:2, each = 5))
  d2 <- data_frame(c = 1:10, d = rep(1:2, each = 5))
  d3 <- group_by(d2, d)
  d4 <- rowwise(d2)
  d5 <- list(c = 1:10, d = rep(1:2, each = 5))

  expect_equal(class(bind_cols(d1, d1)), "data.frame")
  expect_equal(class(bind_cols(d2, d1)), c("tbl_df", "tbl", "data.frame"))
  res3 <- bind_cols(d3, d1)
  expect_equal(class(res3), c("grouped_df", "tbl_df", "tbl", "data.frame"))
  expect_equal(attr(res3, "group_sizes"), c(5, 5))
  expect_equal(class(bind_rows(d4, d1)), c("rowwise_df", "tbl_df", "tbl", "data.frame"))
  expect_equal(class(bind_rows(d5, d1)), c("tbl_df", "tbl", "data.frame"))

})

test_that("bind_rows rejects POSIXlt columns (#1789)", {
  df <- data_frame(x = Sys.time() + 1:12)
  df$y <- as.POSIXlt(df$x)
  expect_error(bind_rows(df, df), "not supported")
})

test_that("bind_rows rejects data frame columns (#2015)", {
  df <- list(
    x = 1:10,
    y = data.frame(a = 1:10, y = 1:10)
  )
  class(df) <- "data.frame"
  attr(df, "row.names") <- .set_row_names(10)

  expect_error(
    dplyr::bind_rows(df, df),
    "Columns of class data.frame not supported",
    fixed = TRUE
  )
})

test_that("bind_rows accepts difftime objects", {
  df1 <- data.frame(x = as.difftime(1, units = "hours"))
  df2 <- data.frame(x = as.difftime(1, units = "mins"))
  res <- bind_rows(df1, df2)
  expect_equal(res$x, as.difftime(c(3600, 60), units = "secs"))
})

test_that("bind_rows accepts hms objects", {
  df1 <- data.frame(x = hms::hms(hours = 1))
  df2 <- data.frame(x = as.difftime(1, units = "mins"))
  res <- bind_rows(df1, df2)
  expect_equal(res$x, hms::hms(hours = c(1, 0), minutes = c(0, 1)))
})
