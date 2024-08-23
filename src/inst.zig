pub const Inst = union(enum) {
    inc_ptr: usize,
    dec_ptr: usize,
    inc_data: usize,
    dec_data: usize,
    jmp_if_zero: usize,
    jmp_if_not_zero: usize,
    read: usize,
    write: usize,
    loop_set_zero,
    move_ptr: isize,
    move_data: isize,
};
