//
//  reconstructscap.swift
//  CutsEditor
//
//  Created by Alan  Franklin on 17/06/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

/* Copyright (C) 2009 Anders Holst
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */
/*
#define _LARGEFILE64_SOURCE
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <dirent.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <byteswap.h>
#include <errno.h>

#define LEN 24064


char* makefilename(const char* dir, const char* base, const char* ext, const char* post)
{
  static char buf[256];
  int len1, len2, len3;
  len1 = (dir ? strlen(dir) : 0);
  len2 = (base ? strlen(base) : 0);
  len3 = (ext ? strlen(ext) : 0);
  if (dir) {
    strcpy(buf, dir);
    if (buf[len1-1] != '/') {
      buf[len1++] = '/';
      buf[len1] = 0;
    }
  }
  if (base) strcpy(buf+len1, base);
  if (ext && len2>=len3 && !strcmp(base+len2-len3,ext)) len2 -= len3;
  if (ext) strcpy(buf+len1+len2, ext);
  if (post) strcpy(buf+len1+len2+len3, post);
  return buf;
}

int writebufinternal(int f, off64_t sz, off64_t tm)
{
  off64_t buf[2];
  buf[0] = (off64_t)bswap_64((unsigned long long int)sz);
  buf[1] = (off64_t)bswap_64((unsigned long long int)tm);
  if (write(f, buf, 16) != 16)
  return 1;
  else
  return 0;
}

int framepid(unsigned char* buf, int pos)
{
  return ((buf[pos+1] & 0x1f) << 8) + buf[pos+2];
}

off64_t framepts(unsigned char* buf, int pos)
{
  int tmp = (buf[pos+3] & 0x20 ? pos+buf[pos+4]+5 : pos+4);
  off64_t pts;
  if (buf[pos+1] & 0x40 &&
    buf[pos+3] & 0x10 &&
    buf[tmp]==0 && buf[tmp+1]==0 && buf[tmp+2]==1 &&
    buf[tmp+7] & 0x80) {
    pts  = ((unsigned long long)(buf[tmp+9]&0xE))  << 29;
    pts |= ((unsigned long long)(buf[tmp+10]&0xFF)) << 22;
    pts |= ((unsigned long long)(buf[tmp+11]&0xFE)) << 14;
    pts |= ((unsigned long long)(buf[tmp+12]&0xFF)) << 7;
    pts |= ((unsigned long long)(buf[tmp+13]&0xFE)) >> 1;
  } else
  pts = -1;
  return pts;
}

int framesearch(int fts, int first, off64_t& retpos, off64_t& retpts, off64_t& retpos2, off64_t& retdat)
{
  static unsigned char buf[LEN];
  static int ind;
  static off64_t pos = -1;
  static off64_t num;
  static int pid = -1;
  static int st = 0;
  static int sdflag = 0;
  unsigned char* p;
  if (pos == -1 || first) {
    num = read(fts, buf, LEN);
    ind = 0;
    pos = 0;
    st = 0;
    sdflag = 0;
    pid = -1;
  }
  while (1) {
    p = buf+ind+st;
    ind = -1;
    for (; p < buf+num-6; p++)
    if (p[0]==0 && p[1]==0 && p[2]==1) {
      ind = ((p - buf)/188)*188;
      if ((p[3] & 0xf0) == 0xe0 && (buf[ind+1] & 0x40) &&
        (p-buf)-ind == (buf[ind+3] & 0x20 ? buf[ind+4] + 5 : 4)) {
        pid = framepid(buf, ind);
      } else if (pid != -1 && pid != framepid(buf, ind)) {
        ind = -1;
        continue;
      }
      if (p[3]==0 || p[3]==0xb3 || p[3]==0xb8) { // MPEG2
        if (p[3]==0xb3) {
          retpts = framepts(buf, ind);
          retpos = pos + ind;
        } else {
          retpts = -1;
          retpos = -1;
        }
        retdat = (unsigned int) p[3] | (p[4]<<8) | (p[5]<<16) | (p[6]<<24);
        retpos2 = pos + (p - buf);
        st = (p - buf) - ind + 1;
        sdflag = 1;
        return 1;
      } else if (!sdflag && p[3]==0x09 && (buf[ind+1] & 0x40)) { // H264
        if ((p[4] >> 5)==0) {
          retpts = framepts(buf, ind);
          retpos = pos + ind;
        } else {
          retpts = -1;
          retpos = -1;
        }
        retdat = p[3] | (p[4]<<8);
        retpos2 = pos + (p - buf);
        st = (p - buf) - ind + 1;
        return 1;
      } else {
        ind = -1;
        continue;
      }
    }
    st = 0;
    sdflag = 0; // reset to get some fault tolerance
    if (num == LEN) {
      pos += num;
      num = read(fts, buf, LEN);
      ind = 0;
    } else if (num!=0) {
      ind = num;
      retpts = 0;
      retdat = 0;
      retpos = pos + num;
      num = 0;
      return -1;
    } else {
      retpts = 0;
      retdat = 0;
      retpos = 0;
      return -1;
    }
  }
}

int do_one(int fts, int fap, int fsc)
{
  off64_t pos;
  off64_t pos2;
  off64_t pts;
  off64_t dat;
  int first = 1;
  while (framesearch(fts, first, pos, pts, pos2, dat) >= 0) {
    first = 0;
    if (pos >= 0 && pts >= 0)
    if (fap >= 0 && writebufinternal(fap, pos, pts))
    return 1;
    if (fsc >= 0 && writebufinternal(fsc, pos2, dat))
    return 1;
  }
  return 0;
}

int do_movie(char* inname)
{
  int f_ts=-1, f_sc=-1, f_ap=-1, f_tmp=-1;
  char* tmpname;
  tmpname = makefilename(0, inname, ".ts", 0);
  f_ts = open(tmpname, O_RDONLY | O_LARGEFILE);
  if (f_ts == -1) {
    printf("Failed to open input stream file \"%s\"\n", tmpname);
    return 1;
  }
  tmpname = makefilename(0, inname, ".ts", ".reconstruct_apsc");
  f_tmp = open(tmpname, O_WRONLY | O_CREAT | O_TRUNC, 0x1a4);
  if (f_tmp == -1) {
    printf("Failed to open sentry file \"%s\"\n", tmpname);
    goto failure;
  }
  close(f_tmp);
  tmpname = makefilename(0, inname, ".ts", ".ap");
  f_ap = open(tmpname, O_WRONLY | O_CREAT | O_TRUNC, 0x1a4);
  if (f_ap == -1) {
    printf("Failed to open output .ap file \"%s\"\n", tmpname);
    goto failure;
  }
  tmpname = makefilename(0, inname, ".ts", ".sc");
  f_sc = open(tmpname, O_WRONLY | O_CREAT | O_TRUNC, 0x1a4);
  if (f_sc == -1) {
    printf("Failed to open output .sc file \"%s\"\n", tmpname);
    goto failure;
  }
  
  printf("  Processing .ap and .sc of \"%s\" ... ", inname);
  fflush(stdout);
  if (do_one(f_ts, f_ap, f_sc)) {
    printf("\nFailed to reconstruct files for \"%s\"\n", inname);
    goto failure;
  }
  printf("done\n");
  
  close(f_ts);
  close(f_ap);
  close(f_sc);
  unlink(makefilename(0, inname, ".ts", ".reconstruct_apsc"));
  return 0;
  failure:
  if (f_ts != -1)
  close(f_ts);
  if (f_ap != -1) {
    close(f_ap);
    unlink(makefilename(0, inname, ".ts", ".ap"));
  }
  if (f_sc != -1) {
    close(f_sc);
    unlink(makefilename(0, inname, ".ts", ".sc"));
  }
  unlink(makefilename(0, inname, ".ts", ".reconstruct_apsc"));
  return 1;
}

int do_directory(char* dirname)
{
  int f_ts, f_sc, f_ap, f_tmp;
  int do_ap, do_sc;
  char *inname, *tmpname;
  DIR* dir = opendir(dirname);
  dirent* entry;
  struct stat statbuf;
  if (dir) {
    while ((entry = readdir(dir))) {
      inname = entry->d_name;
      if (strlen(inname) > 3 && !strcmp(inname + strlen(inname) - 3, ".ts")) {
        tmpname = makefilename(dirname, inname, ".ts", ".reconstruct_apsc");
        errno = 0;
        if (stat(tmpname, &statbuf) != -1)
        do_ap = do_sc = 1;
        else {
          tmpname = makefilename(dirname, inname, ".ts", ".ap");
          errno = 0;
          do_ap = (stat(tmpname, &statbuf) == -1 && errno == ENOENT);
          tmpname = makefilename(dirname, inname, ".ts", ".sc");
          errno = 0;
          do_sc = (stat(tmpname, &statbuf) == -1 && errno == ENOENT);
        }
        if (do_ap || do_sc) {
          f_ts=-1, f_sc=-1, f_ap=-1, f_tmp=-1;
          tmpname = makefilename(dirname, inname, ".ts", 0);
          f_ts = open(tmpname, O_RDONLY | O_LARGEFILE);
          if (f_ts == -1) {
            printf("Failed to open input stream file \"%s\"\n", tmpname);
            continue;
          }
          tmpname = makefilename(dirname, inname, ".ts", ".reconstruct_apsc");
          f_tmp = open(tmpname, O_WRONLY | O_CREAT | O_TRUNC, 0x1a4);
          if (f_tmp == -1) {
            printf("Failed to open sentry file \"%s\"\n", tmpname);
            goto failure;
          }
          close(f_tmp);
          if (do_ap) {
            tmpname = makefilename(dirname, inname, ".ts", ".ap");
            f_ap = open(tmpname, O_WRONLY | O_CREAT | O_TRUNC, 0x1a4);
            if (f_ap == -1) {
              printf("Failed to open output .ap file \"%s\"\n", tmpname);
              goto failure;
            }
          } else
          f_ap = -1;
          if (do_sc) {
            tmpname = makefilename(dirname, inname, ".ts", ".sc");
            f_sc = open(tmpname, O_WRONLY | O_CREAT | O_TRUNC, 0x1a4);
            if (f_sc == -1) {
              printf("Failed to open output .sc file \"%s\"\n", tmpname);
              goto failure;
            }
          } else
          f_sc = -1;
          
          printf("  Processing %s of \"%s\" ... ", (do_ap ? (do_sc ? ".ap and .sc" : ".ap") : ".sc"), inname);
          fflush(stdout);
          if (do_one(f_ts, f_ap, f_sc)) {
            printf("\nFailed to reconstruct files for \"%s\"\n", inname);
            close(f_ts);
            if (f_ap != -1) {
              close(f_ap);
              unlink(makefilename(dirname, inname, ".ts", ".ap"));
            }
            if (f_sc != -1) {
              close(f_sc);
              unlink(makefilename(dirname, inname, ".ts", ".sc"));
            }
            unlink(makefilename(dirname, inname, ".ts", ".reconstruct_apsc"));
            continue;
          }
          printf("done\n");
          
          close(f_ts);
          close(f_ap);
          close(f_sc);
          unlink(makefilename(dirname, inname, ".ts", ".reconstruct_apsc"));
        }
      }
    }
    closedir(dir);
  } else {
    printf("Failed to open directory \"%s\"\n", dirname);
    return 1;
  }
  return 0;
  failure:
  closedir(dir);
  if (f_ts != -1)
  close(f_ts);
  if (f_ap != -1) {
    close(f_ap);
    unlink(makefilename(dirname, inname, ".ts", ".ap"));
  }
  if (f_sc != -1) {
    close(f_sc);
    unlink(makefilename(dirname, inname, ".ts", ".sc"));
  }
  unlink(makefilename(dirname, inname, ".ts", ".reconstruct_apsc"));
  return 1;
}

int main(int argc, char* argv[])
{
  if (argc == 2 && *argv[1] != '-') {
    if (do_movie(argv[1]))
    exit(1);
  } else if (argc == 3 && !strcmp(argv[1], "-d")) {
    if (do_directory(argv[2]))
    exit(1);
  } else {
    printf("Usage: reconstruct_apsc movie_file\n");
    printf("       reconstruct_apsc -d movie_directory\n");
    exit(1);
  }
}/* Copyright (C) 2009 Anders Holst
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

#define _LARGEFILE64_SOURCE
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <dirent.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <byteswap.h>
#include <errno.h>

#define LEN 24064


char* makefilename(const char* dir, const char* base, const char* ext, const char* post)
{
  static char buf[256];
  int len1, len2, len3;
  len1 = (dir ? strlen(dir) : 0);
  len2 = (base ? strlen(base) : 0);
  len3 = (ext ? strlen(ext) : 0);
  if (dir) {
    strcpy(buf, dir);
    if (buf[len1-1] != '/') {
      buf[len1++] = '/';
      buf[len1] = 0;
    }
  }
  if (base)
  strcpy(buf+len1, base);
  if (ext && len2>=len3 && !strcmp(base+len2-len3,ext))
  len2 -= len3;
  if (ext)
  strcpy(buf+len1+len2, ext);
  if (post)
  strcpy(buf+len1+len2+len3, post);
  return buf;
}

int writebufinternal(int f, off64_t sz, off64_t tm)
{
  off64_t buf[2];
  buf[0] = (off64_t)bswap_64((unsigned long long int)sz);
  buf[1] = (off64_t)bswap_64((unsigned long long int)tm);
  if (write(f, buf, 16) != 16)
  return 1;
  else
  return 0;
}

int framepid(unsigned char* buf, int pos)
{
  return ((buf[pos+1] & 0x1f) << 8) + buf[pos+2];
}

off64_t framepts(unsigned char* buf, int pos)
{
  int tmp = (buf[pos+3] & 0x20 ? pos+buf[pos+4]+5 : pos+4);
  off64_t pts;
  if (buf[pos+1] & 0x40 &&
    buf[pos+3] & 0x10 &&
    buf[tmp]==0 && buf[tmp+1]==0 && buf[tmp+2]==1 &&
    buf[tmp+7] & 0x80) {
    pts  = ((unsigned long long)(buf[tmp+9]&0xE))  << 29;
    pts |= ((unsigned long long)(buf[tmp+10]&0xFF)) << 22;
    pts |= ((unsigned long long)(buf[tmp+11]&0xFE)) << 14;
    pts |= ((unsigned long long)(buf[tmp+12]&0xFF)) << 7;
    pts |= ((unsigned long long)(buf[tmp+13]&0xFE)) >> 1;
  } else
  pts = -1;
  return pts;
}

int framesearch(int fts, int first, off64_t& retpos, off64_t& retpts, off64_t& retpos2, off64_t& retdat)
{
  static unsigned char buf[LEN];
  static int ind;
  static off64_t pos = -1;
  static off64_t num;
  static int pid = -1;
  static int st = 0;
  static int sdflag = 0;
  unsigned char* p;
  if (pos == -1 || first) {
    num = read(fts, buf, LEN);
    ind = 0;
    pos = 0;
    st = 0;
    sdflag = 0;
    pid = -1;
  }
  while (1) {
    p = buf+ind+st;
    ind = -1;
    for (; p < buf+num-6; p++)
    if (p[0]==0 && p[1]==0 && p[2]==1) {
      ind = ((p - buf)/188)*188;
      if ((p[3] & 0xf0) == 0xe0 && (buf[ind+1] & 0x40) && (p-buf)-ind == (buf[ind+3] & 0x20 ? buf[ind+4] + 5 : 4)) {
        pid = framepid(buf, ind);
      } else if (pid != -1 && pid != framepid(buf, ind)) {
        ind = -1;
        continue;
      }
      if (p[3]==0 || p[3]==0xb3 || p[3]==0xb8) { // MPEG2
        if (p[3]==0xb3) {
          retpts = framepts(buf, ind);
          retpos = pos + ind;
        } else {
          retpts = -1;
          retpos = -1;
        }
        retdat = (unsigned int) p[3] | (p[4]<<8) | (p[5]<<16) | (p[6]<<24);
        retpos2 = pos + (p - buf);
        st = (p - buf) - ind + 1;
        sdflag = 1;
        return 1;
      } else if (!sdflag && p[3]==0x09 && (buf[ind+1] & 0x40)) { // H264
        if ((p[4] >> 5)==0) {
          retpts = framepts(buf, ind);
          retpos = pos + ind;
        } else {
          retpts = -1;
          retpos = -1;
        }
        retdat = p[3] | (p[4]<<8);
        retpos2 = pos + (p - buf);
        st = (p - buf) - ind + 1;
        return 1;
      } else {
        ind = -1;
        continue;
      }
    }
    st = 0;
    sdflag = 0; // reset to get some fault tolerance
    if (num == LEN) {
      pos += num;
      num = read(fts, buf, LEN);
      ind = 0;
    } else if (num) {
      ind = num;
      retpts = 0;
      retdat = 0;
      retpos = pos + num;
      num = 0;
      return -1;
    } else {
      retpts = 0;
      retdat = 0;
      retpos = 0;
      return -1;
    }
  }
}

int do_one(int fts, int fap, int fsc)
{
  off64_t pos;
  off64_t pos2;
  off64_t pts;
  off64_t dat;
  int first = 1;
  while (framesearch(fts, first, pos, pts, pos2, dat) >= 0) {
    first = 0;
    if (pos >= 0 && pts >= 0)
    if (fap >= 0 && writebufinternal(fap, pos, pts))
    return 1;
    if (fsc >= 0 && writebufinternal(fsc, pos2, dat))
    return 1;
  }
  return 0;
}

int do_movie(char* inname)
{
  int f_ts=-1, f_sc=-1, f_ap=-1, f_tmp=-1;
  char* tmpname;
  tmpname = makefilename(0, inname, ".ts", 0);
  f_ts = open(tmpname, O_RDONLY | O_LARGEFILE);
  if (f_ts == -1) {
    printf("Failed to open input stream file \"%s\"\n", tmpname);
    return 1;
  }
  tmpname = makefilename(0, inname, ".ts", ".reconstruct_apsc");
  f_tmp = open(tmpname, O_WRONLY | O_CREAT | O_TRUNC, 0x1a4);
  if (f_tmp == -1) {
    printf("Failed to open sentry file \"%s\"\n", tmpname);
    goto failure;
  }
  close(f_tmp);
  tmpname = makefilename(0, inname, ".ts", ".ap");
  f_ap = open(tmpname, O_WRONLY | O_CREAT | O_TRUNC, 0x1a4);
  if (f_ap == -1) {
    printf("Failed to open output .ap file \"%s\"\n", tmpname);
    goto failure;
  }
  tmpname = makefilename(0, inname, ".ts", ".sc");
  f_sc = open(tmpname, O_WRONLY | O_CREAT | O_TRUNC, 0x1a4);
  if (f_sc == -1) {
    printf("Failed to open output .sc file \"%s\"\n", tmpname);
    goto failure;
  }
  
  printf("  Processing .ap and .sc of \"%s\" ... ", inname);
  fflush(stdout);
  if (do_one(f_ts, f_ap, f_sc)) {
    printf("\nFailed to reconstruct files for \"%s\"\n", inname);
    goto failure;
  }
  printf("done\n");
  
  close(f_ts);
  close(f_ap);
  close(f_sc);
  unlink(makefilename(0, inname, ".ts", ".reconstruct_apsc"));
  return 0;
  failure:
  if (f_ts != -1)
  close(f_ts);
  if (f_ap != -1) {
    close(f_ap);
    unlink(makefilename(0, inname, ".ts", ".ap"));
  }
  if (f_sc != -1) {
    close(f_sc);
    unlink(makefilename(0, inname, ".ts", ".sc"));
  }
  unlink(makefilename(0, inname, ".ts", ".reconstruct_apsc"));
  return 1;
}

int do_directory(char* dirname)
{
  int f_ts, f_sc, f_ap, f_tmp;
  int do_ap, do_sc;
  char *inname, *tmpname;
  DIR* dir = opendir(dirname);
  dirent* entry;
  struct stat statbuf;
  if (dir) {
    while ((entry = readdir(dir))) {
      inname = entry->d_name;
      if (strlen(inname) > 3 && !strcmp(inname + strlen(inname) - 3, ".ts")) {
        tmpname = makefilename(dirname, inname, ".ts", ".reconstruct_apsc");
        errno = 0;
        if (stat(tmpname, &statbuf) != -1)
        do_ap = do_sc = 1;
        else {
          tmpname = makefilename(dirname, inname, ".ts", ".ap");
          errno = 0;
          do_ap = (stat(tmpname, &statbuf) == -1 && errno == ENOENT);
          tmpname = makefilename(dirname, inname, ".ts", ".sc");
          errno = 0;
          do_sc = (stat(tmpname, &statbuf) == -1 && errno == ENOENT);
        }
        if (do_ap || do_sc) {
          f_ts=-1, f_sc=-1, f_ap=-1, f_tmp=-1;
          tmpname = makefilename(dirname, inname, ".ts", 0);
          f_ts = open(tmpname, O_RDONLY | O_LARGEFILE);
          if (f_ts == -1) {
            printf("Failed to open input stream file \"%s\"\n", tmpname);
            continue;
          }
          tmpname = makefilename(dirname, inname, ".ts", ".reconstruct_apsc");
          f_tmp = open(tmpname, O_WRONLY | O_CREAT | O_TRUNC, 0x1a4);
          if (f_tmp == -1) {
            printf("Failed to open sentry file \"%s\"\n", tmpname);
            goto failure;
          }
          close(f_tmp);
          if (do_ap) {
            tmpname = makefilename(dirname, inname, ".ts", ".ap");
            f_ap = open(tmpname, O_WRONLY | O_CREAT | O_TRUNC, 0x1a4);
            if (f_ap == -1) {
              printf("Failed to open output .ap file \"%s\"\n", tmpname);
              goto failure;
            }
          } else
          f_ap = -1;
          if (do_sc) {
            tmpname = makefilename(dirname, inname, ".ts", ".sc");
            f_sc = open(tmpname, O_WRONLY | O_CREAT | O_TRUNC, 0x1a4);
            if (f_sc == -1) {
              printf("Failed to open output .sc file \"%s\"\n", tmpname);
              goto failure;
            }
          } else
          f_sc = -1;
          
          printf("  Processing %s of \"%s\" ... ", (do_ap ? (do_sc ? ".ap and .sc" : ".ap") : ".sc"), inname);
          fflush(stdout);
          if (do_one(f_ts, f_ap, f_sc)) {
            printf("\nFailed to reconstruct files for \"%s\"\n", inname);
            close(f_ts);
            if (f_ap != -1) {
              close(f_ap);
              unlink(makefilename(dirname, inname, ".ts", ".ap"));
            }
            if (f_sc != -1) {
              close(f_sc);
              unlink(makefilename(dirname, inname, ".ts", ".sc"));
            }
            unlink(makefilename(dirname, inname, ".ts", ".reconstruct_apsc"));
            continue;
          }
          printf("done\n");
          
          close(f_ts);
          close(f_ap);
          close(f_sc);
          unlink(makefilename(dirname, inname, ".ts", ".reconstruct_apsc"));
        }
      }
    }
    closedir(dir);
  } else {
    printf("Failed to open directory \"%s\"\n", dirname);
    return 1;
  }
  return 0;
  failure:
  closedir(dir);
  if (f_ts != -1)
  close(f_ts);
  if (f_ap != -1) {
    close(f_ap);
    unlink(makefilename(dirname, inname, ".ts", ".ap"));
  }
  if (f_sc != -1) {
    close(f_sc);
    unlink(makefilename(dirname, inname, ".ts", ".sc"));
  }
  unlink(makefilename(dirname, inname, ".ts", ".reconstruct_apsc"));
  return 1;
}

int main(int argc, char* argv[])
{
  if (argc == 2 && *argv[1] != '-') {
    if (do_movie(argv[1]))
    exit(1);
  } else if (argc == 3 && !strcmp(argv[1], "-d")) {
    if (do_directory(argv[2]))
    exit(1);
  } else {
    printf("Usage: reconstruct_apsc movie_file\n");
    printf("       reconstruct_apsc -d movie_directory\n");
    exit(1);
  }
} */

import Foundation
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


// functional transcription from C to Swift to gain understanding of ap and sc files

enum MpegAdaptation : Int {  // 4 bit field in storage
  case NoAdaptPayload = 1
  case AdaptNoPayload = 2
  case AdaptPayload   = 3
  case RESERVED       = 0
}

struct Mpeg2PacketHeader        // 4 bytes when packed == 32 bits
{
  var sync : UInt8                           //  8 bits expect 0x47
  var transportErrorIndicator : Int          //  1 bit  TEI
  var payloadUnitStartIndicator : Int        //  1 bit  PUSI
  var transportPriority : Int                //  1 bit  TP
  var pid: Int                               // 13 bits of packed data
  var transportScrambling: Int               //  2 bits TSC
  var adaptationFieldControl: MpegAdaptation //  2 bits AFC
  var continuityCounter: Int                 //  4 bits
  
  init(byteArray:[UInt8]) {
    self.sync = byteArray[0]
    self.transportErrorIndicator = Int(byteArray[1] & 0x80) >> 7
    self.payloadUnitStartIndicator = Int(byteArray[1] & 0x40) >> 6
    self.transportPriority = Int(byteArray[1] & 0x20) >> 5
    self.pid = (Int((byteArray[1]) & 0x1F) << 8) + Int(byteArray[2])
    self.transportScrambling = Int(byteArray[3]&0xA0) >> 6
    self.adaptationFieldControl = MpegAdaptation(rawValue: (Int(byteArray[3] & 0x30) >> 4))!
    self.continuityCounter = (Int(byteArray[3]) & 0x0F)
  }
}

struct TSAdaptationField {
  var fieldLength : Int                    // for completness
  var discontinuityIndicator: Int          // 1 bit DI
  var randomAccessIndicator: Int           // 1 bit RAI
  var ESPriorityIndicator: Int             // 1 bit ESPI
  
  var PF: Int                               // 1 bit flag ProgramClockReference
  var OF: Int                               // 1 bit flag OrigProgramClockReference
  var SPF: Int                              // 1 bit flag Splice CountDown
  var TPDF: Int                             // 1 bit flag Transport Private Data Flag
  var AFEF: Int                             // 1 bit flag Adaptation Field Extension Field Length
  
  // optional field 1
  var PCR: UInt64                           // 42 bit flag 48?  33+6+9
  var OPCR: UInt64                          // 42 bit flag 48?  33+6+9
  var SpliceCountdown: UInt8                // 8 bit
  var TransPrivateDataLength: UInt8         // 8 bit
  var TransPrivateData: [UInt8]?            // array size of above
  var AdaptationFieldExtensionLength: Int   // 8 bit
  var LTWF: Int                               // 1 bit lf (LegalTimeWindowFlag)
  var PRF: Int                              // 1 bit PiecewiseRateFlag
  var SSF: Int                              // 1 bit SSF (SeamlessSpliceFlag)
  var reserved: Int                         // 5 bits
  
  // extension field
  var ltwValid: Int                         // 1 bit
  var ltwOffset: Int                        // 15 bits
                                            // Extra information for rebroadcasters to determine the state of buffers when packets may be missing.
  
  var PieceWiseRate: Int                    // 2+22 bits ? (2 bit fill in msb)
                                            // lsb 22 - The rate of the stream, measured in 188-byte packets, to define the end-time of the LTW.
  
  var SpliceType: Int                       // 4 bits
  var DTSNextAu: Int                        // 36 bits 33+3
  var reserved2: Int                        // 8 bits
  
  init(byteArray: [UInt8]) {
    self.fieldLength = Int(byteArray[0])
    self.discontinuityIndicator = Int(byteArray[1] & 0x80) >> 7
    self.randomAccessIndicator = Int(byteArray[1] & 0x40) >> 6
    self.ESPriorityIndicator = Int(byteArray[1] & 0x20) >> 5
    
    self.PF = Int(byteArray[1] & 0x10) >> 4
    self.OF = Int(byteArray[1] & 0x08) >> 3
    self.SPF = Int(byteArray[1] & 0x04) >> 2
    self.TPDF = Int(byteArray[1] & 0x02) >> 1
    self.AFEF = Int(byteArray[1] & 0x01) >> 0
    
    // initialize option fields to zero or nil, then populate if present
    self.PCR = 0
    self.OPCR = 0
    self.SpliceCountdown = 0
    self.TransPrivateDataLength = 0
    self.TransPrivateData = nil
    self.AdaptationFieldExtensionLength = 0
    self.LTWF = 0
    self.PRF = 0
    self.SSF = 0
    self.reserved = 0
    
    // initialize extension fields to zero, then populate if present
    self.ltwValid = 0
    self.ltwOffset = 0
    self.PieceWiseRate = 0
    self.SpliceType = 0
    self.DTSNextAu = 0
    self.reserved2 = 0
    
    // do we have any optional fields ?
    var pos = 2
    if (self.PF == 1 || self.OF == 1 || self.SPF == 1 || self.TPDF == 1 || self.AFEF == 1) {
      if (self.PF == 1) {
        self.PCR = UInt64(byteArray[pos]) << 40
        self.PCR |= UInt64(byteArray[pos+1]) << 32
        self.PCR |=  UInt64(byteArray[pos+2]) << 24
        self.PCR |= UInt64(byteArray[pos+3]) << 16
        self.PCR |= UInt64(byteArray[pos+4]) << 8
        self.PCR |= UInt64(byteArray[pos+5])
        pos += 6
      }
      if (self.OPCR == 1) {
        self.OPCR = UInt64(byteArray[pos]) << 40 & UInt64(byteArray[pos+1]) << 32
        self.OPCR |= UInt64(byteArray[pos+2]) << 24 & UInt64(byteArray[pos+3]) << 16
        self.OPCR |= UInt64(byteArray[pos+4]) << 8 & UInt64(byteArray[pos+5])
        pos += 6
      }
      if (self.SPF == 1) {
        self.SpliceCountdown = UInt8(byteArray[pos])
        pos += 1
      }
      if (self.TPDF == 1) {
        self.TransPrivateDataLength = UInt8(byteArray[pos])
        pos += 1
      }
      if (self.TPDF == 1 && self.TransPrivateDataLength > 0)
      {
        self.TransPrivateData = [UInt8](repeating: 0, count: Int(self.TransPrivateDataLength))
        for i in 0 ..< Int(self.TransPrivateDataLength) {
          self.TransPrivateData![i] = byteArray[i+pos]
        }
      }
      pos += Int(self.TransPrivateDataLength)
      if (self.AFEF == 1) {
        self.AdaptationFieldExtensionLength = Int(byteArray[pos])  // this may include the stuffing bytes I think
        pos += 1
        self.LTWF = Int(byteArray[pos] & 0x80) >> 7
        self.PRF = Int(byteArray[pos] & 0x40) >> 6
        self.SSF = Int(byteArray[pos] & 0x20) >> 5
        self.reserved = Int(byteArray[pos] & 0x1F)
        pos += 1
        if (self.LTWF == 1) {
          self.ltwValid = Int(byteArray[pos] & 0x80) >> 7                           // valid flag
          self.ltwOffset = Int(byteArray[pos] & 0x7F) << 8 & Int(byteArray[pos+1])  // 15 bits
          pos += 2
        }
        
        if (self.PRF == 1) {
          self.PieceWiseRate = Int(byteArray[pos] & 0x3F) << 16 & Int(byteArray[pos+1]) << 8 & Int(byteArray[pos+2]) // 22 bit number
          pos += 3
        }
        
        if (self.SSF == 1) {
          self.SpliceType = Int(byteArray[pos] & 0xF0) >> 4
          self.DTSNextAu = Int(byteArray[pos] & 0x0F) << 24 & Int(byteArray[pos+1]) << 16 & Int(byteArray[pos+2]) << 8
          self.DTSNextAu &= Int(byteArray[pos+3])
          pos += 4
        }
      }
    }
    // if I got it right the next byte should be a suffing byte - let's check
//    if (pos < self.fieldLength && byteArray[pos] == 0xFF) {
//      print("woo hoo!")
//    }
//    else {
//      print("argh.... better luck nex time")
//    }
  }
}

typealias PtsType = UInt64
typealias OffType = UInt64
typealias OffPts = (offset: OffType, pts: PtsType)

class reconstructScAp
{
  static let LEN = 24064
  static var buf = [UInt8]() // = [UInt8](count: LEN, repeatedValue: 0)
  static var ind : Int = 0
  static var pos = OffType.max;
//  static var num = 0
  static var numBytesRead = 0
  static var pid = Int(-1)
  static var st = Int(0)
  static var sdflag = Int(0)
  static var lastFileReadPos = OffType(0)
  
  
  static func framepid(_ buf: inout [UInt8], pos:Int ) -> Int
  {
    // 13 bit pid
    let pid = (Int(buf[pos+1]) & 0x1f) << 8 + Int(buf[pos+2])
    return pid
  }
  
  // no idea what this bit fiddling really does.....
  // I think it picks out a uint64 bit field spread that
  // crosses 5 bytes
  
  static func framepts(_ buf: inout [UInt8], pos:Int ) -> PtsType
  {
    let t1 = (buf[pos+3] & 0x20)
    let t2 = (pos+Int(buf[pos+4]) + 5)
    let tmp = Int(( t1 == 0 ? t2 : pos+4))
    var pts : PtsType
    // I think this sequence of checks identifies a "Start Of Frame" position
    // and returns the correspoding ProgramTimeStamp
    if ((buf[pos+1] & 0x40) == 0 &&
        (buf[pos+3] & 0x10) == 0 &&
        buf[tmp]==0 &&
        buf[tmp+1]==0 &&
        buf[tmp+2]==1 &&
        (buf[tmp+7] & 0x80) == 0)
    {
      pts  = (PtsType(buf[tmp+9]&0xE))   << 29
      pts |= (PtsType(buf[tmp+10]&0xFF)) << 22
      pts |= (PtsType(buf[tmp+11]&0xFE)) << 14
      pts |= (PtsType(buf[tmp+12]&0xFF)) << 7
      pts |= (PtsType(buf[tmp+13]&0xFE)) >> 1
    }
    else
    {
      pts = UInt64.max  // -1
    }
    return pts
 }

  static func readBuf(_ filename: String, maxReadByteCount: Int, fromPos: UInt64) -> [UInt8]?
  {
    var buf : [UInt8]?
    var data : Data
    if FileManager.default.fileExists(atPath: filename) {
      if let fileHandle = FileHandle(forReadingAtPath: filename)
      {
        fileHandle.seek(toFileOffset: fromPos)
        data = fileHandle.readData(ofLength: maxReadByteCount)
        fileHandle.closeFile()
        buf = [UInt8](repeating: 0, count: data.count)
        (data as NSData).getBytes(&(buf!), length:data.count*MemoryLayout<UInt8>.size)
        return buf
      }
    }
    return buf
  }
  
  static func writebufinternal(_ filename: String, sz: UInt64, tm: UInt64) -> Bool
  {
    let item = NSMutableData()
    
    var size = sz.bigEndian
    var time = tm.bigEndian
    item.append(&size, length: MemoryLayout<UInt64>.size)
    item.append(&time, length: MemoryLayout<UInt64>.size)
    
    if FileManager.default.fileExists(atPath: filename) {
      if let fileHandle = FileHandle(forWritingAtPath: filename) {
        fileHandle.seekToEndOfFile()
        fileHandle.write(item as Data)
        fileHandle.closeFile()
        return true
      }
      else {
        print("Can't open fileHandle")
        return false
      }
    }
    else {
      if !item.write(toFile: filename, atomically: true) {
        print("Can't write ")
        return false
      }
    }
    return false
  }

  
  // build a full filename like /blah/blah/movie.ts.ap
  // from /blah/blah movie .ts .ap
  
  // typical call makefilename(dirname, inname, ".ts", ".reconstruct_apsc")
  
    static func makefilename(_ dir: String?, base: String?, ext: String?, post: String?) -> String
    {
      var buf : String = ""
      // ensure dir name ends with "/"
      if (dir != nil) {
        buf = dir!
        if (buf.characters.last != Character("/")) {
          buf += "/"
        }
      }
      
      if let baseName = base {
        buf += baseName
      }
      
      if let extn = ext {
        if (!(buf.hasSuffix(extn))) {
          buf += extn
        }
      }
      if let postfix = post {
        buf += postfix
      }
      return buf
    }
  
  static func framesearch( _ fileTS: String,  first: Bool, retpos: inout UInt64, retpts: inout UInt64, retpos2: inout UInt64, retdat: inout UInt64) -> Int
  {
//    unsigned char* p;
    if (pos == UInt64.max || first)
    {
      ind = 0;
      pos = 0;
      st = 0;
      sdflag = 0;
      pid = -1;
      
      buf = readBuf(fileTS, maxReadByteCount: LEN, fromPos: lastFileReadPos)!
      numBytesRead = buf.count
      lastFileReadPos += UInt64(numBytesRead)
    }
    var passes = 0
    while (true)
    {
      var buffIndex = ind + st // p = buf+ind+st;
      
      ind = -1;
      while (buffIndex < numBytesRead-6)
      {
        if (buf[buffIndex]==0 && buf[buffIndex+1]==0 && buf[buffIndex+2]==1)  // frame marker ?
        {
          ind = ((buffIndex)/188)*188  // rouding to start of packet position ?
          let flag1 = ((buf[buffIndex+3] & 0xf0) == 0xe0)
          let flag2 = (buf[ind+1] & 0x40) != UInt8(0)
          let value3a = (((buf[ind+3] & 0x20) != UInt8(0)) ? buf[ind+4] + UInt8(5) : UInt8(4))
          let flag3 = ((buffIndex-ind) == Int(value3a))
          if ( flag1 && flag2 && flag3 )
          {
            pid = framepid(&buf, pos: ind)
          }
          else if (pid != -1 && pid != framepid(&buf, pos: ind))
          {
            ind = -1;
            buffIndex += 1
            continue
          }
          if (buf[buffIndex+3]==0 || buf[buffIndex+3]==0xb3 || buf[buffIndex+3]==0xb8)
          { // MPEG2
            print("Found MPEG2 packet")
            if (buf[buffIndex+3]==0xb3)
            {
              retpts = framepts(&buf, pos: ind)
              retpos = pos + UInt64(ind)
            }
            else
            {
              retpts = UInt64.max
              retpos = UInt64.max
            }
            // fabricate a 64 bit from bytes
            let b0 = UInt64(buf[buffIndex+3])
            let b1 = UInt64(buf[buffIndex+4])<<8
            let b2 = UInt64(buf[buffIndex+5])<<16
            let b3 = UInt64(buf[buffIndex+6])<<24
            retdat =  b0 | b1 | b2 | b3
            let ptsInSeconds = Double(retdat)/90_000.0  // 90 KHz clock
            let ptsInSecondsString = String(format: "%10.2f", ptsInSeconds)
            retpos2 = pos + UInt64(buffIndex)
            print("Returning SC dat value of \(ptsInSecondsString) at buffer index of \(retpos2)")
            st = buffIndex - ind + 1;
            sdflag = 1;
            return 1;
          }
          else if ((sdflag == 0) && buf[buffIndex+3]==0x09 && ((buf[ind+1] & 0x40) == 0))
          { // H264
            if ((buf[buffIndex+4] >> 5)==0)
            {
              retpts = framepts(&buf, pos: ind)
              retpos = pos + UInt64(ind)
            }
            else
            {
              retpts = UInt64.max
              retpos = UInt64.max
            }
            retdat = UInt64(buf[buffIndex+3]) | UInt64(buf[buffIndex+4])<<8
            retpos2 = pos + UInt64(buffIndex)
            st = buffIndex - ind + 1;
            return 1;
          }
          else
          {
            ind = -1;
          }
        }
        buffIndex += 1
        if ((buffIndex % 4096) == 0) {
          print ("at \(buffIndex)")
        }
      }
      st = 0;
      sdflag = 0; // reset to get some fault tolerance
      if (numBytesRead == LEN)
      {
        passes += 1
        
        pos += UInt64(numBytesRead)
        print ("next chunk from \(lastFileReadPos)")
        buf  = readBuf(fileTS, maxReadByteCount: LEN, fromPos: lastFileReadPos)!
        lastFileReadPos += UInt64(buf.count)
        numBytesRead = buf.count
        ind = 0;
      }
      else if (numBytesRead != 0)
      {
        ind = numBytesRead;
        retpts = 0;
        retdat = 0;
        retpos = pos + UInt64(numBytesRead)
        numBytesRead = 0;
        return -1;
      }
      else
      {
        retpts = 0;
        retdat = 0;
        retpos = 0;
        return -1;
      }
    }
  }
  
  //  while (framesearch(fts, first, pos, pts, pos2, dat) >= 0) {
  //    first = 0;
  //    if (pos >= 0 && pts >= 0)
  //      if (fap >= 0 && writebufinternal(fap, pos, pts))
  //        return 1;
  //    if (fsc >= 0 && writebufinternal(fsc, pos2, dat))
  //      return 1;
  //  }
  //  return 0;
  
  static func do_one(_ filets: String, fileap :String ,  filesc: String) -> Bool
  {
    var pos: UInt64 = 0
    var pos2: UInt64 = 0
    var pts: UInt64 = 0
    var dat: UInt64 = 0
    
    var first = true
    while (framesearch(filets, first: first, retpos: &pos, retpts: &pts, retpos2: &pos2, retdat: &dat) >= 0)
    {
      first = false
      print("lastFile: \(lastFileReadPos) ... pos:\(pos) retpts:\(pts) retpos2: \(pos2) retdat:\(dat)")
      if (pos >= UInt64(0) && pts >= UInt64(0)) {
        if (!writebufinternal(fileap, sz: pos, tm: pts))
        {
          return false
        }
      }
      if (!writebufinternal(filesc, sz: pos2, tm: dat))
      {
        return false
      }
    }
    return true
  }
 
  // precond: filename has be validated
  
  static func createOpenFileForWrite(_ filename: String) -> Bool
  {
    let fileManager = FileManager.default
    if ( fileManager.fileExists(atPath: filename)) {
      do {
        try fileManager.removeItem(atPath: filename)
      }
      catch let error as NSError {
        print("failed to remove existing file \(filename) .. \(error)")
        return false
      }
    }
    if ( !fileManager.createFile(atPath: filename, contents: nil, attributes: nil))
    {
      print("create failed for \(filename) ... ")
    }
    
    if let fileHandle = FileHandle(forWritingAtPath: filename)
    {
      fileHandle.closeFile()
    }
    else
    {
      print("failed to open file \(filename) for writing")
      return false
    }
    return true
  }
  
  static func do_movie(_ inname:String) -> Bool
  {
    var f_ts : String
    var f_sc : String
    var f_ap : String
//    var f_tmp : String
    
    f_ts = makefilename(nil, base: inname, ext: ".ts", post: nil)
    if let fileHandle = FileHandle(forReadingAtPath: f_ts)
    {
      fileHandle.closeFile()
    }
    else
    {
      print("failed to open\(f_ts) for reading")
      return false
    }
    
//    f_tmp = makefilename(nil, base: inname, ext: ".ts", post: ".reconstruct_apsc");
//    if (!createOpenFileForWrite(f_tmp)) {
//      return false
//    }
    
    f_ap = makefilename(nil, base: inname, ext: ".ts", post: ".ap")
    if (!createOpenFileForWrite(f_ap)) {
      return false
    }
    
    f_sc = makefilename(nil, base: inname, ext: ".ts", post: ".sc")
    if (!createOpenFileForWrite(f_ap)) {
      return false
    }
    
    print("  Processing .ap and .sc of <\(inname)> ... ")
    fflush(stdout)
    
//============================
//    junk testing code
//============================
    
    if (true) {
      f_sc.append(".abc")
      if let fileHandle = FileHandle(forReadingAtPath: f_sc)
      {
        var pairArray = Array<OffPts>()
        var buf : [UInt64]?
        var cacheCounter = 0
        var data : Data
        let entryCount = 5000
        var readFromPos = UInt64(0)
        let maxReadByteCount = entryCount*16
        var moreToRead = true
//        let magic :[UInt64] = [0x0F0000000000,
//                               0x4F0000000000,
//                               0x8F0000000000,
//                               0xCF0000000000]
        while (moreToRead) {
          
          var dat = UInt64(0)
          fileHandle.seek(toFileOffset: readFromPos)
          data = fileHandle.readData(ofLength: maxReadByteCount)
          buf = [UInt64](repeating: 0xFFFFffffFFFFffff, count: data.count/8)
          (data as NSData).getBytes(&(buf!), length:data.count*MemoryLayout<UInt8>.size)
          print(String(format:"%15.15s, %15.15s", "field1".cString(using: String.Encoding.utf8)!, "field2".cString(using: String.Encoding.utf8)!))
          print("===========================================================")
          for index in 0 ..< min(entryCount/2, data.count/(8*2))
          {
            cacheCounter += 1
            let pos2 = buf![index].bigEndian
//            if (magic.contains(buf![index*2+1])) {
//              dat = 0xFFFFffffFFFFffff
//              print("-------------------> Saw Magic value.................")
//            } else {
              dat = buf![index*2+1].bigEndian
//            }
            
            pairArray.append((pos2,dat))
            print(String(format:"%15.lu, %15.lu (%16.16lx)", pos2, dat, dat))
          }
          moreToRead = data.count == maxReadByteCount
          print("------------block \(data.count) processed from \(readFromPos) ---------------------------------")
          readFromPos += UInt64(maxReadByteCount)
        }
        print("Saw \(cacheCounter) pairs in file")
        let pairArray2 = pairArray.sorted(by: {$0.offset < $1.offset})
//        print(pairArray)
        var checkvalue = OffType(0)
        for entry in pairArray2 {
          var thisPts = entry.pts
          if (thisPts & 0x001000000 != 0) {
            // value is mpg encoded, strip out the pts element
            thisPts = UInt64(entry.pts >> 31)
          }
          print(String(format:"%15.lu, %15.lu (%16.16lx)", entry.offset, thisPts, entry.pts))
          if (entry.offset < checkvalue) {
            print(" sort failed....!")
            break;
          }
          else {
            checkvalue = entry.offset
          }
        }
//        let altPairArray = pairArray.sort({$1.pts < $1.pts})
//        print (altPairArray)
        fileHandle.closeFile()
      }
      else
      {
        print("failed to open\(f_sc) for reading")
        return false
      }
    }
    
    // end of junk testing code *******************************
    
    if (do_one(f_ts, fileap: f_ap, filesc: f_sc)) {
      print("\nFailed to reconstruct files for <\(inname)>")
    }
    print("done")
    
//    close(f_ts);
//    close(f_ap);
//    close(f_sc);
//    let fileManager = NSFileManager.defaultManager()
//      do {
//        try fileManager.removeItemAtPath(f_tmp)
//      }
//      catch let error as NSError {
//        print("Something went wrong \(error)")
//    }
//    unlink(makefilename(nil, base: inname, ext: ".ts", post: ".reconstruct_apsc"));
    return true;
    // exception catching code
//    failure:
//    if (f_ts != -1)
//      close(f_ts);
//      if (f_ap != -1) {
//      close(f_ap);
//      unlink(makefilename(0, inname, ".ts", ".ap"));
//    }
//    if (f_sc != -1) {
//      close(f_sc);
//      unlink(makefilename(0, inname, ".ts", ".sc"));
//    }
//    unlink(makefilename(0, inname, ".ts", ".reconstruct_apsc"));
//    return 1;
  }

  static func readFFMeta(_ filename: String)
  {
    let filemanager = FileManager.default
    if (filemanager.fileExists(atPath: filename)) {
      let fileHandle = FileHandle(forReadingAtPath: filename)
      let data = fileHandle?.readDataToEndOfFile()
      fileHandle?.closeFile()
      print("file size was \(data?.count)")
      var a = UInt64(0)
      var b = UInt64(0)
      var fieldRange = NSMakeRange(0, MemoryLayout<UInt64>.size)
      while (fieldRange.location < data?.count) {
        (data as NSData?)?.getBytes(&a, range:fieldRange)
        fieldRange.location += MemoryLayout<UInt64>.size
        (data as NSData?)?.getBytes(&b, range:fieldRange)
        fieldRange.location += MemoryLayout<UInt64>.size
        print("a= \(a), b= \(b)")
      }
    }
  }
  
  static var tsFileHandle: FileHandle? = nil
  static var pyBufIndex = 0
  static var pidTable = [Int](repeating: 0, count: 12) // table to store PID's seen in headers
  static var payloadStartCounter = 0
  static var adaptationCounter = 0
  
  // pid as string, pid is 13 bits 0..8192 0x0000..0x1FFF
  
  static func PIDString(_ pidValue: UInt16) -> String
  {
    let asHex = String.init(format: "%0.4X", pidValue)
    print(asHex)
    switch (pidValue)
    {
      case 0x00: return "PAT (Program Association Table)"
      case 0x01: return "CAT (Conditional Access Module)"
      case 0x02...0x0F : return "Reserved (Should not apppear)"
      case 0x10: return "Network Information Table"
      case 0x11: return "SDT, BAT, ST (Service Des, Bouquet Inf & Stuffing )"
      case 0x12: return "Event Info Table (EIT)"
      case 0x13: return "Running Status Table and Stuffing Tab (RST, ST)"
      case 0x14: return "TDT, TOT, ST (Time/Date, Time Offset, Stuffing)"
      case 0x0015...0x001F: return "Reserved 2 (Should not Appear)"
      case 0x20...0x1FFE: return "Video/Audio/Private"
      case 0x1FFF: return "NULL packets"
      case 0xF000...0xFFFF: return "Invalid - Out of Range"
    default: return "bull shit case is complete"
    }
  }
  
  // tsName is full path/URL of file to be processed
  // packetOffset  - restart point in semi-processed read (currently Unused)
  // maxlen - debugging value to give up after processing maxlen bytes
  // returns retPts, retPos, retDat, retPos2, EndOfFileSeen
  
  static func pyFrameGenerator(_ tsName:String, packetOffset: UInt64 = UInt64(0), maxlen:Int64 = Int64(-1)) -> (retPts: UInt64, retPos: UInt64, retDat: UInt64, retPos2: UInt64, EndOfFileSeen: Bool)
  {
    var EndOfFileSeen : Bool = false
    let PACKET_SIZE = 188
    var packetBuf = [UInt8]()
    let BUFFERLEN = PACKET_SIZE*128
    
    if (tsFileHandle == nil) {
       tsFileHandle = FileHandle.init(forReadingAtPath: tsName)
      lastFileReadPos = UInt64(0)
    }
    buf.removeAll()
    buf = readBuf(tsName, maxReadByteCount: BUFFERLEN, fromPos: lastFileReadPos)!
    pyBufIndex = 0
    EndOfFileSeen = buf.count < BUFFERLEN
    let thisBuffFilePos = lastFileReadPos
    lastFileReadPos += UInt64(buf.count)
    var leftInBuffer = buf.count - pyBufIndex
    var pid = -1
    var streamtype = -1
    var packetCount = 0
    while leftInBuffer > PACKET_SIZE && pyBufIndex < buf.count {  // skip partial packets if corruption has crept in
      // seek to sync marker
//      print("index = \(pyBufIndex) \(buf[pyBufIndex])")
      while buf[pyBufIndex] != 0x47 && pyBufIndex < buf.count {
        print(buf[pyBufIndex])
        pyBufIndex += 1
      }
      // out of data or found sync
      if pyBufIndex >= buf.count {
        continue
      }
      // safe to decode header
      let filePos = thisBuffFilePos + UInt64( pyBufIndex)
      
      // fabricate a packet (array slice from overall buffer)
      packetBuf.removeAll()
      packetBuf = Array(buf[pyBufIndex..<pyBufIndex+PACKET_SIZE])
      let packetHeader = Mpeg2PacketHeader(byteArray: packetBuf)
//      print(packetHeader)
      if (!pidTable.contains(packetHeader.pid))
      {
        print("Saw a pid of type \(PIDString(UInt16(packetHeader.pid)))")
        pidTable.append(packetHeader.pid)
      }
      if (packetHeader.payloadUnitStartIndicator == 1)
      {
        payloadStartCounter += 1
//        print("payloads = \(payloadStartCounter)")
      }
      if (packetHeader.adaptationFieldControl == MpegAdaptation.AdaptNoPayload || packetHeader.adaptationFieldControl == MpegAdaptation.AdaptPayload)
      {
        adaptationCounter += 1
//        print("Saw adaptation Control \(adaptationCounter)")
      }
      packetCount += 1
//      print("built packet No \(packetCount)")
      pyBufIndex += PACKET_SIZE
      
      
      // decode adaptation field if present to adjust pointer to skip
      // over adaptation data and point at payload data only if present
      
      var lengthOfAdaptationField: Int = 0
      var startOfPayloadPos = 0
      if (packetHeader.adaptationFieldControl == .AdaptPayload || packetHeader.adaptationFieldControl == .AdaptNoPayload ) {
        lengthOfAdaptationField = Int(packetBuf[4])  // should not exceed balance of packet size
        
        // create a splice of the adaptation data
        let adaptBuffer = Array(packetBuf[4...4+lengthOfAdaptationField])
        let adaptationField = TSAdaptationField(byteArray: adaptBuffer)
//        print(packetHeader.adaptationFieldControl)
        if (packetHeader.adaptationFieldControl ==  .AdaptPayload) {
          startOfPayloadPos = lengthOfAdaptationField + 5
        }
        
      }
      else if (packetHeader.adaptationFieldControl == .NoAdaptPayload) // for purposes of doco and completness
      {  //
        startOfPayloadPos = 4
      }
      
 // skip packet with no payload
      if ( packetHeader.adaptationFieldControl == .AdaptNoPayload || packetHeader.adaptationFieldControl == .RESERVED) {
        // no payload or unknown, skip this packet
        continue
      }
/*  debug
    
//      let offsetAdaption = ((packetBuf[3] & 0x20 == 0) ? 4 : 5)
//      var packetPos = Int(packetBuf[4]) + offsetAdaption
      var packetPos = startOfPayload
      if (packetPos >= PACKET_SIZE) {
        continue
      }
      
//      // extract packet pid
//      let tpid = (Int(packetBuf[1] & 0x1F) << 8) | Int(packetBuf[2])
      let thisPid = packetHeader.pid
      // get video pid
      let packetPidIsVideoPid  = !((packetBuf[packetPos] != 0 ) || (packetBuf[packetPos+1] != 0) || ((packetBuf[packetPos+2] & 0x01) == 0))
      && (packetBuf[packetPos+3] & 0xF0) == 0xE0 && packetHeader.payloadUnitStartIndicator == 1
      if packetPidIsVideoPid
      {
        pid = thisPid
      }
      else if (pid >= 0 && pid != thisPid) { // mismatch, packet of no interest
        continue
      }

      var pts = UInt64.max
      if (packetHeader.payloadUnitStartIndicator == 1) { // Pusi ?
        if ((packetBuf[packetPos] != 0) || (packetBuf[packetPos+1] != 0) || ((packetBuf[packetPos+2] & 0x01) == 0)) {  // expect three bytes 0x00 0x00 0x01
          print(" broken start code")
          continue
        }
        if ((packetBuf[7] & 0x80 ) != 0) { // PTS present ?
          let b0 = UInt64(packetBuf[packetPos +  9] & 0x0E) << 29
          let b1 = UInt64(packetBuf[packetPos + 10] & 0xFF) << 22
          let b2 = UInt64(packetBuf[packetPos + 11] & 0xFE) << 14
          let b3 = UInt64(packetBuf[packetPos + 12] & 0xFF) << 7
          let b4 = UInt64(packetBuf[packetPos + 13] & 0xFE) >> 1
          pts = b0 | b1 | b2 | b3 | b4
        }
        packetPos = Int(buf[packetPos+8]) + 9
      }
        
      while packetPos < (PACKET_SIZE - 4) {
        if ((packetBuf[packetPos] == 0) && (packetBuf[packetPos+1] == 0) && ((packetBuf[packetPos+2] & 0x01) == 0x01)) {  // expect three bytes 0x00 0x00 0x01
          let sc = packetBuf[packetPos+3]
          if streamtype < 0 {  // unknown
            if [0x00, 0xB3, 0xB9].contains(sc)
            {
              streamtype = 0
//              print("detected MPEG2 stream type")
            }
            else if [0x09].contains(sc)
            {
              streamtype = 1
              print("detected H264 stream type")
            }
            else {
              packetPos += 1
              continue
            }
          }
          if (streamtype == 0) {  // MPEG2
            if [0x00, 0xB3, 0xB9].contains(sc)    // pictures, sequence, group start code
            {
              var retPos = UInt64.max
              var retPts = UInt64.max
              var retDat = UInt64.max
              var retPos2 = UInt64.max
              if sc == 0xB3 && pts >= 0 { // sequence header
                retPos = filePos
                retPts = pts
              }
              if (packetPos < PACKET_SIZE - 6)
              {
                retDat = UInt64(sc) | (UInt64(packetBuf[packetPos+4])) << 8 | (UInt64(packetBuf[packetPos+5])) << 16
                if (pts >= 0) {
                  retDat |= pts << 31 | 0x1000000
                  retPos2 = filePos + UInt64(packetPos)
                }
              }
//              print("mpeg2 returning (pts,pos) \(retPts), \(retPos),  -  (dat,pos) \(retDat), \(retPos2)")
              return (retPts, retPos, retDat, retPos2, EndOfFileSeen)
            }
          }
          if (streamtype == 1) {  // H264
            if sc == 0x09
            {
              var retPos = UInt64.max
              var retPts = UInt64.max
              var retDat = UInt64.max
              var retPos2 = UInt64.max
              
              retDat = UInt64(sc) | (UInt64(packetBuf[packetPos+4]) << 8)
              retPos2 = filePos + UInt64(packetPos)
              if ((packetBuf[packetPos] & 0x60) == 0) {
                if pts >= 0
                {
                  retPos = filePos
                  retPts = pts
                }
              }
//              print("h264 returning (pts,pos) \(retPts), \(retPos),  -  (dat,pos) \(retDat), \(retPos2)")

              return (retPts, retPos, retDat, retPos2, EndOfFileSeen)
            }
          }
          
        }
        packetPos += 1
      }
 */
      leftInBuffer = buf.count - pyBufIndex
    }
    return (UInt64.allZeros,UInt64.allZeros,UInt64.allZeros,UInt64.allZeros, EndOfFileSeen)
  }
  
  static func getFileSize(_ name:String) -> UInt64
  {
    var fileSize = UInt64(0)
    
    do {
      let attr :NSDictionary? = try FileManager.default.attributesOfItem(atPath: name) as NSDictionary?
      fileSize = (attr?.fileSize())!
    }
    catch {
      print("error - \(error)")
    }
    return fileSize
  }
  
  static func pyProcessScAp(_ tsName:String, maxlen : Int64 = Int64(-1))
  {
    let fileSize = getFileSize(tsName)
    let apFilename = makefilename(nil, base: tsName, ext: "ts", post: "ap")
    let scFilename = makefilename(nil, base: tsName, ext: "ts", post: "sc")
    var lastprogress = -1
    var progress = 0
    pidTable.removeAll()
    var (pts, pos, dat, pos2, endOfFile) = pyFrameGenerator(tsName, maxlen: maxlen)
//    for i in 0x00...0x20 {
//      print("\(i) \(PIDString(UInt16(i)))")
//    }
//    print("\(0x1FFF) \(PIDString(0x1FFF))")
    while(!endOfFile)
    {
//      let p1 = (pos != UInt64.max) ? pos : 0
//      let p2 = (pos2 != UInt64.max) ? pos2 : 0
//      let curpos = Double(max(p1,p2))
//      if (curpos > 0.0) {
//         progress = curpos*100.0/Double(fileSize)
//      }
      progress = Int(100.0*Double(lastFileReadPos)/Double(fileSize))
      if (progress > lastprogress)
      {
        print("processed \(progress)%")
        lastprogress = progress
      }
      if (pts != UInt64.max && pos != UInt64.max )
      {
        writebufinternal(apFilename, sz: pts, tm: pos)
      }
      if (dat != UInt64.max && pos2 != UInt64.max)
      {
        writebufinternal(scFilename, sz: dat, tm: pos2)
      }
      (pts, pos, dat, pos2, endOfFile) = pyFrameGenerator(tsName, maxlen: maxlen)
    }
    print(pidTable)
  }
}
