#define CAML_NAME_SPACE
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/callback.h>

CAMLextern value * caml_stack_low;
CAMLextern value * caml_stack_high;
CAMLextern value * caml_stack_threshold;
CAMLextern value * caml_extern_sp;
CAMLextern value * caml_trapsp;
CAMLextern value * caml_trap_barrier;

extern code_t caml_start_code;
extern asize_t caml_code_size;
extern unsigned char * caml_saved_code;

int caml_debugger_in_use;

enum event_kind { /* sync with debugger.h */
  EVENT_COUNT, BREAKPOINT, PROGRAM_START, PROGRAM_EXIT,
  TRAP_BARRIER, UNCAUGHT_EXC
};

void caml_set_instruction (code_t pos, opcode_t instr);

#define GETTER(name) value pry_ ## name(value Unit) { return (value) caml_ ## name; }
GETTER(stack_low)
GETTER(stack_high)
GETTER(extern_sp)
GETTER(trapsp)
GETTER(trap_barrier)
#undef GETTER

void pry_set_instruction(code_t pos, value opcode) {
  caml_set_instruction(pos, Int_val(opcode));
}

void pry_reset_instruction(code_t pos) {
  caml_set_instruction(pos, *(pos - caml_start_code + caml_saved_code));
}

code_t pry_pc_to_code(value pc) {
  return caml_start_code + Int_val(pc) / sizeof(opcode_t);
}

value pry_pc_of_code(code_t pos) {
  return Val_long((pos - caml_start_code) * sizeof(opcode_t));
}

value pry_in_bounds(void *low, void *high, void *ptr) {
  return Val_int(ptr >= low && ptr < high);
}

void __wrap_caml_debugger_init() {
  caml_debugger_in_use = 1;
  caml_trap_barrier = caml_stack_high;
}

void __wrap_caml_debugger(enum event_kind event) {
  value *callback = caml_named_value("Pry_agent.callback");
  if (callback)
    caml_callback2(*callback, Val_int(event), (value) caml_extern_sp);
}

void __wrap_caml_debugger_cleanup_fork() {
  /* nothing to do */
}
