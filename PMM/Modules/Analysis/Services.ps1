# Shared composition root. Loading does not initialize the game or deploy anything.
foreach($relative in @('Shared/Paths.ps1','Shared/Common.ps1','Shared/Persistence.ps1','Shared/GameLocator.ps1','Merge/PakService.ps1','Library/LibraryService.ps1','CKL/SemanticLab.ps1','GameReference/GameReferenceService.ps1','CKL/KnowledgeRecipeService.ps1','Knowledge/Knowledge.Service.ps1','Merge/MergeEngine.ps1','AIIO/AIIO.SessionService.ps1','AIIO/AIIO.CaseWorkspaceService.ps1','Cases/CaseService.ps1','MCP/MCP.Service.ps1','Analysis/Analysis.Model.ps1','Analysis/Nexus.Client.ps1','Analysis/Updates.Service.ps1','Analysis/Repair.Service.ps1','Analysis/Analysis.Guards.ps1','Analysis/Updates.Stage.ps1','Analysis/Analysis.Service.ps1','Analysis/Updates.Transaction.ps1','MCP/MCP.Client.ps1','MCP/AI.Policy.ps1','MCP/AppServer.Client.ps1')){
  . (Join-Path $Script:Root ('Modules/'+$relative))
}
Initialize-PMMPaths $Script:Root|Out-Null
