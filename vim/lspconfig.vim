vim9script

var lspServers = [
{
    name: 'clang',
    filetype: ['c', 'cpp'],
    path: '/usr/bin/clangd',
    args: ['--background-index']
},
{
    name: 'pylsp',
    filetype: 'python',
    path: '/home/lucas/.local/bin/pylsp',
    args: ['--check-parent-process', '-v']
},]
# {
#     name: 'texlab',
#     filetype: ['tex'],
#     path: '/usr/bin/texlab',
# },

var lspOpts = {
   aleSupport: v:false,
   autoComplete: v:true,
   autoHighlight: v:true,
   autoHighlightDiags: v:true,
   autoPopulateDiags: v:false,
   completionMatcher: 'case',
   completionTextEdit: v:false,
   completionKinds: {},
   customCompletionKinds: v:false,
   diagSignErrorText: 'E>',
   diagSignInfoText: 'I>',
   diagSignHintText: 'H>',
   diagSignWarningText: 'W>',
   diagVirtualTextAlign: 'above',
   echoSignature: v:false,
   hideDisabledCodeActions: v:false,
   highlightDiagInline: v:true,
   hoverInPreview: v:false,
   ignoreMissingServer: v:false,
   keepFocusInReferences: v:false,
   noNewlineInCompletion: v:false,
   outlineOnRight: v:false,
   outlineWinSize: 20,
   showDiagInBalloon: v:true,
   showDiagInPopup: v:true,
   showDiagOnStatusLine: v:false,
   showDiagWithSign: v:true,
   showDiagWithVirtualText: v:false,
   showInlayHints: v:false,
   showSignature: v:true,
   snippetSupport: v:false,
   ultisnipsSupport: v:false,
   usePopupInCodeAction: v:false,
   useQuickfixForLocations: v:false,
   useBufferCompletion: v:true,
}

autocmd VimEnter * call LspAddServer(lspServers)
autocmd VimEnter * call LspOptionsSet(lspOpts)
