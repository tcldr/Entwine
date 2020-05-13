#!/usr/bin/awk -f
BEGIN { FS=":"; errCode=0; }
{
  if(match($0,/^.+:[0-9]+:[0-9]+: error: /)) {
     message=substr($0,RSTART+RLENGTH); file=$1; gsub("^"prefix"/","",file);
     printf("::error file=%s,line=%s,col=%s::%s\n", file, $2, $3, message);
     errCode=1;
  } else {
    print;
  }
}
END { exit errCode; }
