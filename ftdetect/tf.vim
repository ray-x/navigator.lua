autocmd BufRead,BufNewFile *.tf,*.tfvars set filetype=terraform
autocmd BufRead,BufNewFile *.tfstate,*.tfstate.backup set filetype=json
autocmd BufRead,BufNewFile *.hcl set filetype=hcl
autocmd BufRead,BufNewFile .terraformrc,terraform.rc set filetype=hcl
