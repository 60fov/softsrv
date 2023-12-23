#include "image.h"
#include <stdlib.h>
#include <string.h>

struct split_path_t {
  char *dir;
  char *name;
  char *ext;
};

char *path_ext(const char *path) {
  size_t len = strlen(path);
  size_t size = 0;
  size_t i = 0;
  while ((i = len - size) > 0) {
    char c = path[i];
    if (c == '.') {
      break;
    }
    size += 1;
  }

  char *result = (char *)malloc(sizeof(char) * size);
  memcpy(result, path + i, size);
  return result;
}

bitmap_t image_load(const char *filepath) {
  char *ext = path_ext(filepath);
  
  if (strcmp(ext, "ppm") == 0) {
    return image_load_ppm(filepath);
  } else if (strcmp(ext, "bmp") == 0) {
    // return image_load_bmp(filepath);
  } else if (strcmp(ext, "tga") == 0) {
    // return image_load_tga(filepath);
  }
}

bitmap_t image_load_ppm(const char *filepath) {

}
// bitmap_t image_load_tga(const char *filepath) {}
// bitmap_t image_load_bmp(const char *filepath) {}