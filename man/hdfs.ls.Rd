\name{ssh.pipe}
\alias{ssh.pipe}
\title{Execute remote comamnds via a pipe through ssh}
\usage{
ssh.pipe(cmd, host="localhost", user="", open.mode="")
hdfs.ls(args, host="analytix", user="")
hdfs.du(args, host="analytix", user="")
hdfs.copyToLocal(src.path, host="analytix", user="", dest.path=src.path)
}
\description{
Exeecutes a remote command via a ssh pipe conection.
}
\examples{
## list (unix) files on a remote cluster (defaults to analytix)
ssh.pipe("ls")

## list files in hdfs and return a dataframe with all results (careful if recursive)
hdfs.ls("-R /project/itmon")

## calculate hdfs consumed user volume and raw volume (usually raw == user*3 )
hdfs.du("/project/itmon")

## retrieve all input files
itmon <- data.table(hdfs.ls("-R /project/itmon"))
## and sum up all which have .tmp in their names (aka leftovers)
sum(itmon[ path %like% ".tmp"]$size)

## copy a file from the remote cluster to the current directory on the local machine
hdfs.copyToLocal("lemonbi201602oneday.csv")
}
