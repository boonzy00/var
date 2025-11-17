#ifndef VAR_H
#define VAR_H

typedef enum { CPU, GPU } Decision;

Decision route(float query_size, float world_size);

#endif
