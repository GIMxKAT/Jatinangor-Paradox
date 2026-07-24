--!strict
-- CaretakerGreeting — reference dialog tree. Copy this file's shape for
-- any new NPC conversation; DialogSystem never needs to change to pick it
-- up.

local CaretakerGreeting = {
    Id = "CaretakerGreeting",
    DisplayName = "Caretaker Greeting",
    RootNodeId = "Start",
    Nodes = {
        Start = {
            Id = "Start",
            Text = "You're new here. The old amphitheater has been sealed for years — be careful.",
            Options = {
                { Text = "What happened here?", NextNodeId = "History" },
                { Text = "Never mind.", NextNodeId = nil },
            },
        },
        History = {
            Id = "History",
            Text = "Nobody quite agrees. Find the journal fragments — they'll tell you more than I can.",
            Options = nil, -- terminal node
        },
    },
}

return CaretakerGreeting
