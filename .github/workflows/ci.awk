#!/usr/bin/awk -f
BEGIN { FS=":"; errCode=0; mask=fails_on_warning==1?"(error|warning)":"error"; }
{
  if(match($0,"^.+:[0-9]+:[0-9]+:[ ]*"mask":[ ]*")) {
     message=substr($0,RSTART+RLENGTH); file=$1; gsub("^"prefix"/","",file);
     printf("::error file=%s,line=%s,col=%s::%s\n", file, $2, $3, message);
     errCode=1;
  } else if(match($0,"^.+:[0-9]+:[ ]*"mask":[ ]*")) {
     message=substr($0,RSTART+RLENGTH); file=$1; gsub("^"prefix"/","",file);
     printf("::error file=%s,line=%s::%s\n", file, $2, message);
     errCode=1;
  } else if(match($0,/^.+:[0-9]+:[ ]*\*\*\*[ ]*/)) {
     message=substr($0,RSTART+RLENGTH); file=$1; gsub("^"prefix"/","",file);
     printf("::error file=%s,line=%s::%s\n", file, $2, message);
     errCode=1;
  } else if(match($0,/^make:[ ]*\*\*\*[ ]*/)) {
     message=substr($0,RSTART+RLENGTH); file=$1; gsub("^"prefix"/","",file);
     printf("::error ::%s\n", message);
     errCode=1;
     print;
  } else {
     print;
  }
}
END { exit errCode; }
