from Cheetah.Template import Template

context = {
    'module_name' : 'gen_pulse_reg',
    'addr_w' : 32,
    'data_w' : 32,
    'reg_addr_w' : 8,

    'regs' : [
        {
            'reg_name'   : 'reg_0',
            'reg_descr'  : 'Register 0',
            'reg_type'   : 'rw',
            'reg_addr'   : 'h00',
            'reg_fields' : [
                {
                    'field_name'  : 'field_0',
                    'field_descr' : 'Field 0',
                    'field_bits'  : [15,0],
                    'reset_value' : 'hffff'
                },
                {
                    'field_name'  : 'field_1',
                    'field_descr' : 'Field 1',
                    'field_bits'  : [31,16],
                    'reset_value' : 'h1234'
                }
            ]
        },
        {
            'reg_name'   : 'reg_1',
            'reg_descr'  : 'Register 1',
            'reg_type'   : 'ro',
            'reg_addr'   : 'h04',
            'reg_fields' : [
                {
                    'field_name'  : 'field_0',
                    'field_descr' : 'Field 0',
                    'field_bits'  : [7,0],
                    'reset_value' : 'hff'
                },
                {
                    'field_name'  : 'field_1',
                    'field_descr' : 'Field 1',
                    'field_bits'  : [15,8],
                    'reset_value' : 'hab'
                },
                {
                    'field_name'  : 'field_2',
                    'field_descr' : 'Field 2',
                    'field_bits'  : [23,16],
                    'reset_value' : 'hcd'
                },
                {
                    'field_name'  : 'field_3',
                    'field_descr' : 'Field 3',
                    'field_bits'  : [31,24],
                    'reset_value' : 'hde'
                }
            ]
        },
        {
            'reg_name'   : 'reg_2',
            'reg_descr'  : 'Register 2',
            'reg_type'   : 'const',
            'reg_addr'   : 'h08',
            'reg_fields' : [
                {
                    'field_name'  : 'field_0',
                    'field_descr' : 'Field 0',
                    'field_bits'  : [31,0],
                    'reset_value' : 'hdeadbeef'
                }
            ]
        }
    ]
}


print Template(file = 'reg_model_v.tmpl', searchList = [context])
