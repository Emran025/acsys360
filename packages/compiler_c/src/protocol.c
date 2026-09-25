#include "protocol.h"

int compiler_driver_run(const char *payload);

int c_run_protocol(const char *payload) {
  return compiler_driver_run(payload);
}
