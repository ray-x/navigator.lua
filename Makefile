PACKER_DIR = ~/.local/share/nvim/site/pack/vendor/start
localtestsetup:
	@mkdir -p $(PACKER_DIR)
	@mkdir -p ~/tmp

	@test -d $(PACKER_DIR)/plenary.nvim ||\
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(PACKER_DIR)/plenary.nvim

	@test -d $(PACKER_DIR)/nvim-lspconfig ||\
		git clone --depth 1 https://github.com/neovim/nvim-lspconfig $(PACKER_DIR)/nvim-lspconfig

	@test -d $(PACKER_DIR)/guihua.lua ||\
		git clone --depth 1 https://github.com/ray-x/guihua.lua $(PACKER_DIR)/guihua.lua

	@test -d $(PACKER_DIR)/nvim-treesitter ||\
		git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter $(PACKER_DIR)/nvim-treesitter

	@test -d $(PACKER_DIR)/navigator.lua || ln -s ${shell pwd} $(PACKER_DIR)


localtestts: localtestsetup
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedFile tests/treesitter_spec.lua"

test:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/ "
