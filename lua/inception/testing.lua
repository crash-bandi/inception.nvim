-- print(vim.inspect(require("inception.config")))
require("inception.api").create_new_workspace("test1")
print(vim.inspect(require("inception.manager").workspaces))

require("inception.manager"):open_workspace(1)
print(vim.inspect(require("inception.manager")))

