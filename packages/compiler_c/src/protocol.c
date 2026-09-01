#include "protocol.h"

#include <stdio.h>

int c_run_protocol(const char *payload) {
  (void)payload;
  fputs("{\"protocolVersion\":\"0.5.0\",\"success\":false,\"diagnostics\":[{\"severity\":\"error\",\"phase\":\"backend\",\"code\":\"C000\",\"message\":\"مترجم C قيد النقل المرحلي ولم يُربط بواجهة الإنتاج بعد\",\"span\":null}],\"tokens\":[],\"syntaxTree\":null,\"symbolTable\":[],\"threeAddressCode\":[],\"assembly\":\"\",\"executionOutput\":[],\"artifacts\":[],\"intermediateRepresentation\":null}\n", stdout);
  return 1;
}
