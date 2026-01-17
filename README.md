# SsHDFS - SSH-based HDFS Access for R

An R package that provides convenient wrapper functions around SSH and HDFS command-line tools to interact with remote Hadoop clusters without requiring local Hadoop installation.

## Overview

SsHDFS allows you to:
- List and query HDFS files and directories
- Check disk usage on HDFS
- Download files from HDFS
- Stream HDFS file contents directly into R data structures
- Execute remote HDFS commands via SSH pipes

## Key Features

- **No local Hadoop required** - Uses SSH to execute HDFS commands remotely
- **Pipe-based streaming** - Efficient memory usage through R pipes
- **Data frame integration** - Works seamlessly with R's data manipulation tools
- **Authentication via SSH** - Leverages existing SSH key or Kerberos authentication

## Prerequisites

### Required Software
- R (>= 3.0.0)
- SSH client (`ssh` command must be available in PATH)
- Remote access to a Hadoop cluster with HDFS command-line tools

### Authentication Setup

This package assumes SSH authentication is already configured. Set up one of:

1. **SSH Key Authentication** (recommended):
   ```bash
   ssh-copy-id user@hadoop-host
   ```

2. **Kerberos Authentication**:
   ```bash
   kinit username@REALM
   ```

Test your connection:
```bash
ssh your-hadoop-host "hdfs dfs -ls /"
```

## Installation

```r
# Install from source
devtools::install_github("yourusername/SsHDFS")

# Or install locally
install.packages("path/to/SsHDFS", repos = NULL, type = "source")
```

## Quick Start

```r
library(SsHDFS)

# List files in HDFS directory
files <- hdfs.ls("-R /user/yourname", host = "hadoop-host")
head(files)

# Check disk usage
usage <- hdfs.du("/user/yourname/data", host = "hadoop-host")
print(usage)

# Download a file from HDFS
hdfs.copyToLocal("/user/yourname/results.csv",
                 host = "hadoop-host",
                 dest.path = "local_results.csv")

# Stream CSV data directly into R
data <- read.csv(hdfs.cat("/user/yourname/data.csv", host = "hadoop-host"))

# Read large files efficiently
pipe_conn <- hdfs.cat("/user/yourname/big_file.txt", host = "hadoop-host")
chunk <- readLines(pipe_conn, n = 1000)  # Read first 1000 lines
close(pipe_conn)
```

## Function Reference

### Core Functions

#### `ssh.pipe(cmd, host, user, open.mode)`
Execute remote commands via SSH pipe.

**Parameters:**
- `cmd` - Command string to execute
- `host` - Hostname or SSH config alias (default: "localhost")
- `user` - Remote username (default: "")
- `open.mode` - Pipe open mode; use "rb" for binary (default: "")

**Returns:** Open pipe connection

**Example:**
```r
# List remote directory
readLines(ssh.pipe("ls -la", host = "hadoop-host"))
```

#### `hdfs.ls(args, host, user)`
Scan HDFS directory and return metadata as data frame.

**Parameters:**
- `args` - Arguments for `hdfs dfs -ls` command
- `host` - Remote host (default: "analytix")
- `user` - Remote user (default: "")

**Returns:** Data frame with columns: `perm`, `user`, `group`, `size`, `path`, `mdate`

**Example:**
```r
# Recursive listing
files <- hdfs.ls("-R /project/data", host = "hadoop-host")

# Filter large files
large_files <- files[files$size > 1e9, ]

# Find recent files
recent <- files[files$mdate > Sys.time() - 86400, ]
```

#### `hdfs.du(args, host, user)`
Report HDFS disk usage.

**Parameters:**
- `args` - Path to query
- `host` - Remote host (default: "analytix")
- `user` - Remote user (default: "")

**Returns:** Data frame with columns: `user.size`, `raw.size`, `path`

**Example:**
```r
# Check project disk usage
usage <- hdfs.du("/project/*", host = "hadoop-host")

# Sort by size
usage[order(-usage$user.size), ]
```

#### `hdfs.copyToLocal(src.path, host, user, dest.path)`
Copy file from HDFS to local filesystem.

**Parameters:**
- `src.path` - HDFS source path
- `host` - Remote host (default: "analytix")
- `user` - Remote user (default: "")
- `dest.path` - Local destination (default: same as `src.path`)

**Example:**
```r
# Download file
hdfs.copyToLocal("/user/data/results.txt",
                 host = "hadoop-host",
                 dest.path = "results.txt")

# Download to specific location
hdfs.copyToLocal("/user/data/report.pdf",
                 host = "hadoop-host",
                 dest.path = "/tmp/report.pdf")
```

#### `hdfs.cat(src.path, host, user)`
Stream HDFS file contents via pipe.

**Parameters:**
- `src.path` - HDFS file path
- `host` - Remote host (default: "analytix")
- `user` - Remote user (default: "")

**Returns:** Open binary pipe to file contents

**Example:**
```r
# Read CSV directly
data <- read.csv(hdfs.cat("/user/data/dataset.csv", host = "hadoop-host"))

# Read compressed file
data <- read.csv(gzcon(hdfs.cat("/user/data/dataset.csv.gz", host = "hadoop-host")))

# Read in chunks
pipe_conn <- hdfs.cat("/user/data/large.txt", host = "hadoop-host")
while (length(chunk <- readLines(pipe_conn, n = 1000)) > 0) {
  process(chunk)
}
close(pipe_conn)
```

## Best Practices

### 1. Always Close Pipes
Pipes must be consumed and closed to avoid descriptor leaks:

```r
# Good
p <- hdfs.cat("/data/file.txt", host = "hadoop-host")
data <- readLines(p)
close(p)

# Better - automatic cleanup
data <- readLines(hdfs.cat("/data/file.txt", host = "hadoop-host"))
```

### 2. Use SSH Config
Simplify host configuration in `~/.ssh/config`:

```
Host hadoop
    HostName hadoop-cluster.example.com
    User yourname
    IdentityFile ~/.ssh/hadoop_key
```

Then use short alias:
```r
hdfs.ls("/user/yourname", host = "hadoop")
```

### 3. Handle Large Files Efficiently
Stream large files instead of loading entirely into memory:

```r
# Don't do this for large files
data <- read.csv(hdfs.cat("/huge/file.csv", host = "hadoop-host"))

# Do this instead
library(data.table)
data <- fread(hdfs.cat("/huge/file.csv", host = "hadoop-host"))

# Or process in chunks
process_chunks <- function(file_path, chunk_size = 10000) {
  conn <- hdfs.cat(file_path, host = "hadoop-host")
  on.exit(close(conn))

  while (length(chunk <- readLines(conn, n = chunk_size)) > 0) {
    # Process chunk
    result <- analyze(chunk)
    save_results(result)
  }
}
```

## Configuration

### Default Host
Avoid repeating host parameter by setting a default:

```r
# At the start of your script
.hdfs_host <- "hadoop-cluster"

# Use in function calls
hdfs.ls("/data", host = .hdfs_host)
```

### Environment Variables
You can set up shell aliases or environment variables:

```r
# In your .Rprofile
Sys.setenv(HDFS_HOST = "hadoop-cluster")

# Then create wrapper functions
my_hdfs.ls <- function(args, user = "") {
  hdfs.ls(args, host = Sys.getenv("HDFS_HOST"), user = user)
}
```

## Troubleshooting

### Connection Issues

**Problem:** "Permission denied" or "Connection refused"

**Solution:**
1. Test SSH connection: `ssh your-hadoop-host`
2. Check SSH key permissions: `chmod 600 ~/.ssh/id_rsa`
3. Verify Kerberos ticket: `klist`

### Command Failures

**Problem:** HDFS commands fail silently

**Solution:**
Enable debugging to see actual commands:
```r
ssh.pipe.debug <- function(cmd, host = "localhost", user = "", open.mode = "") {
  connect.str <- if (nchar(user)) paste0(user, "@", host) else host
  remote.cmd <- paste("ssh", connect.str, cmd)
  message("Executing: ", remote.cmd)  # Debug output
  pipe(remote.cmd, open = open.mode)
}
```

### Memory Issues

**Problem:** Running out of memory with large files

**Solution:** Use streaming instead of loading entire files:
```r
# Use chunked processing
# Use data.table::fread() instead of read.csv()
# Close pipes promptly
```

## Limitations

- **Security:** Input is not sanitized; avoid using untrusted user input
- **Error handling:** Limited error reporting from remote commands
- **Operations:** Only read operations implemented (no put, rm, mkdir, etc.)
- **Authentication:** Must be configured outside of R
- **Platform:** Requires Unix-like system with SSH client

## Contributing

Contributions are welcome! Please see `IMPROVEMENTS.md` for identified enhancement opportunities.

## License

GPL

## Author

Dirk Duellmann <dirk@dirkduellmann.com>

## See Also

- [Apache Hadoop HDFS Documentation](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/HdfsUserGuide.html)
- [rhdfs package](https://github.com/RevolutionAnalytics/RHadoop/wiki) - Alternative using Java HDFS client
