from Cheetah.Template import Template

# context = {'name':'!', 'retVal':'!', 'args':'!', 'funcBody':'!', 'isVirtual':'!', 'isCallBase':'!'}
context = {
    'module_name' : 'wb_nic',
    'addr_w' : 32,
    'data_w' : 32,
    'base_addr_w' : 4,

    'masters' : [
        {'name':'ctrl'},
        {'name':'ldrv'},
        {'name':'imgd'} ],
    'masters_n' : 3,

    'slaves' : [
        {'name':'spi',  'base':'h1'},
        {'name':'bmgr', 'base':'h2'},
        {'name':'mem',  'base':'h3'} ]
    }

print Template(file = 'wb_nic_v.tmpl', searchList = [context])
