//
//  Header.h
//  
//
//  Created by Sven Mischkewitz on 19.09.23.
//

#ifndef libcurl_h
#define libcurl_h

#include <stdbool.h>
#include <curl/curl.h>

// NOTE(sven): Variadic functions cannot be imported into swift, so we build a simple
// bridge here for the most important functions that we will need.

static CURLcode curl_easy_setopt_string(CURL *curl, CURLoption option, const char *param) {
    return curl_easy_setopt(curl, option, param);
}

typedef size_t (*curl_func)(char *buffer, size_t size, size_t num_items, void *user_data);
static CURLcode curl_easy_setopt_func(CURL *curl, CURLoption option, curl_func param) {
    return curl_easy_setopt(curl, option, param);
}

static CURLcode curl_easy_setopt_pointer(CURL *curl, CURLoption option, void* param) {
    return curl_easy_setopt(curl, option, param);
}

static CURLcode curl_easy_setopt_slist(CURL *handle, CURLoption option, struct curl_slist * value)
{
  return curl_easy_setopt(handle, option, value);
}

static CURLcode curl_easy_setopt_long(CURL *handle, CURLoption option, long value)
{
  return curl_easy_setopt(handle, option, value);
}

#endif /* Header_h */
