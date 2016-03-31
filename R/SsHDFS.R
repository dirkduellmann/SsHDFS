##
## R wrapper around ssh and hdfs commandline tools to interact remote with a hadoop cluster via ssh
##
## - support simple file system query/summary operations
## - allow to up/download fractions of the HDFS space for automated consumption from interactive or batch R
##
## main idea:
## - assume that authentication is handled on ssh level via ssh keys or kerberos
##  -> no passwords or other credential in here, but all access fails if not autheticated already
##
## - interact via data frames as main data type
##  -> make it simple to use data.table, but do not require the package internally

## most of the package uses piped ssh execution to avoid local data copies
## remember: pipes need to be consumed & closed to avoid descriptor leaks
## -> the usual pattern would be eg:
## > readLines(ssh.pipe("ls"))
##
ssh.pipe <- function(cmd, host="localhost", user="", open.mode="") {
    connect.str <- if (nchar(user)) paste0(user,"@", host) else host
    remote.cmd <- paste("ssh",connect.str, cmd)
    ## debug with: message("executing: ", remote.cmd)
    pipe(remote.cmd, open=open.mode)
}

## scan a directory and return relevant meta data as data frame
hdfs.ls <- function(args, host="analytix", user=""){
  p <- ssh.pipe(paste("hdfs dfs -ls", args), host = host, user = user)
  df <- read.table(p,skip=1, col.names=c("perm","links", "user", "group", "size", "date", "time", "path"))

  ## convert to appropriate representation
  df$user  <- as.factor(df$user)
  df$group <- as.factor(df$group)
  df$mdate <- as.POSIXct(paste(df$date,df$time))

  ## drop a few fields which are not used yet
  df$date  <- NULL
  df$time  <- NULL
  df$links <- NULL

  df
}

hdfs.du <- function(args, host="analytix", user="") {
  p <- ssh.pipe(paste("hdfs dfs -du -s", args), host = host, user = user)
  df <- read.table(p, col.names=c("user.size","raw.size", "path"))

  df
}

hdfs.copyToLocal <- function(src.path, host="analytix", user="", dest.path=src.path)  {
  p <- ssh.pipe(paste("hdfs dfs -cat", src.path), host = host, user = user, open.mode="rb")

  ## open the pipe in binary mode
  dst <- file(dest.path,"wb")

  ## do a copy from the pipe in 16 chunks
  buf.size <- 16*1024

  repeat {
    buf <- readBin(p, "raw", buf.size)
    writeBin(buf,dst)

    ## until we did not get a full buffer
    if (length(buf) != buf.size){
        close(dst)
        break
      }
  }
}




