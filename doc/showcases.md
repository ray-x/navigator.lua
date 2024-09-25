# Screenshots and videos of the app in action


## Golang struct type

Struct type references in multiple Go 󰟓  files

![go_reference](https://user-images.githubusercontent.com/1681295/119123823-54b3b180-ba73-11eb-8790-097601e10f6a.gif)

This feature can provide you info in which function/class/method the variable was referenced. It is handy for a large
project where class/function definition is too long to fit into the preview window. Also provides a bird's eye view of where the
variable is:

- Referenced
- Modified
- Defined
- Called


### Definition preview

Using treesitter and LSP to view the symbol definition

![image](https://user-images.githubusercontent.com/1681295/139771978-bbc970a5-be9f-42cf-8942-3477485bd89c.png)

### Sidebar, folding, outline

Treesitter outline and Diagnostics
<img width="708" alt="image" src="https://user-images.githubusercontent.com/1681295/174791609-0023e68f-f1f4-4335-9ea2-d2360e9f0bfd.png">
<img width="733" alt="image" src="https://user-images.githubusercontent.com/1681295/174804579-26f87fbf-426b-46d0-a7a3-a5aab69c032f.png">

The side panel is vim buffer. You can toggle folds with za/zo/zc


Calltree (Expandable LSP call hierarchy)
<img width="769" alt="image" src="https://user-images.githubusercontent.com/1681295/176998572-e39fc968-4c8c-475d-b3b8-fb7991663646.png">

### GUI and multigrid support

You can load a different font size for floating win

![multigrid2](https://user-images.githubusercontent.com/1681295/139196378-bf69ade9-c916-42a9-a91f-cccb39b9c4eb.jpg)

### Document Symbol and navigate through the list

![doc_symbol_and_navigate](https://user-images.githubusercontent.com/1681295/148642747-1870b1a4-67c2-4a0d-8a41-d462ecdc663e.gif)
The key binding to navigate in the list.

- up and down key
- `<Ctrl-f/b>` for page up and down
- number key 1~9 go to the ith item.
- If there are loads of results, would be good to use fzy search prompt to filter out the result you are interested.

### Workspace Symbol

![workspace symbol](https://github.com/ray-x/files/blob/master/img/navigator/workspace_symbol.gif?raw=true)

### highlight document symbol and jump between reference

![multiple_symbol_hi3](https://user-images.githubusercontent.com/1681295/120067627-f9f80680-c0bf-11eb-9216-18e5c8547f59.gif)

## Current symbol highlight and jump backward/forward between symbols

Document highlight provided by LSP.
Jump between symbols with treesitter (with `]r` and `[r`)
![doc jump](https://github.com/ray-x/files/blob/master/img/navigator/doc_hl_jump.gif?raw=true)

### Diagnostic

Visual studio code style show errors minimap in scroll bar area
(Check setup for `diagnostic_scrollbar_sign`)

![diagnostic_scroll_bar](https://user-images.githubusercontent.com/1681295/128736430-e365523d-810c-4c16-a3b4-c74969f45f0b.jpg)

Diagnostic in single bufer

![diagnostic](https://github.com/ray-x/files/blob/master/img/navigator/diag.jpg?raw=true)

Show diagnostic in all buffers

![diagnostic multi files](https://github.com/ray-x/files/blob/master/img/navigator/diagnostic_multiplefiles.jpg?raw=true)

### Edit in preview window

You can in place edit your code in floating window

<https://user-images.githubusercontent.com/1681295/121832919-89cbc080-cd0e-11eb-9778-11d0f356b38d.mov>

(Note: This feature only available in `find reference` and `find diagnostic`, You can not add/remove lines in floating window)

### Implementation

![implementation](https://user-images.githubusercontent.com/1681295/118735346-967e0580-b883-11eb-8c1e-88c5810f7e05.jpg?raw=true)

### Fzy search in reference

![fzy_reference](https://github.com/ray-x/files/blob/master/img/navigator/fzy_reference.jpg?raw=true)

### Code actions

![code actions](https://github.com/ray-x/files/blob/master/img/navigator/codeaction.jpg?raw=true)

### Symbol rename

<https://user-images.githubusercontent.com/1681295/200327179-0fc84660-44a8-4ee1-9631-2cc7a17b0b12.mov>

#### Fill struct with gopls

![code actions fill struct](https://github.com/ray-x/files/blob/master/img/navigator/fill_struct.gif?raw=true)

### Code preview with highlight

![treesitter_preview](https://user-images.githubusercontent.com/1681295/118900852-4bccbe00-b955-11eb-82f6-0747b1b64e7c.jpg)

### Treesitter symbol

Treetsitter symbols in all buffers
![treesitter](https://user-images.githubusercontent.com/1681295/118734953-cc6eba00-b882-11eb-9db8-0a052630d57e.jpg?raw=true)

### Call hierarchy (incoming/outgoing calls)

![incomming_calls](https://user-images.githubusercontent.com/1681295/142348079-49b71486-4f16-4f10-95c9-483aad11c262.jpg)

### Light bulb if codeAction available

![lightbulb](https://github.com/ray-x/files/blob/master/img/navigator/lightbulb.jpg?raw=true)

### Codelens

Codelens for gopls/golang. Garbage collection analyse:

![codelens](https://user-images.githubusercontent.com/1681295/132428956-7835bf30-2ed5-4871-b2d7-7fbad22f63e8.jpg)

Codelens for C++/ccls. Symbol reference

![codelens_cpp_ccls](https://user-images.githubusercontent.com/1681295/132429134-abc6547e-79cc-44a4-b7a9-23550b895e51.jpg)

### Predefined LSP symbol nerdfont/emoji

![nerdfont](https://github.com/ray-x/files/blob/master/img/navigator/icon_nerd.jpg?raw=true)

### Signature help

Improved signature help with current parameter highlighted

![signature](https://github.com/ray-x/files/blob/master/img/navigator/signature_with_highlight.jpg?raw=true)

![show_signature](https://github.com/ray-x/files/blob/master/img/navigator/show_signnature.gif?raw=true "show_signature")

