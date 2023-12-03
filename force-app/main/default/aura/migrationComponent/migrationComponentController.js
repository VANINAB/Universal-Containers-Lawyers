({
    startMigration : function(component, event, helper) {
        var action = component.get("c.callHerokuIntegration");
        action.setCallback(this, function(response) {
            var state = response.getState();
            var toastEvent = $A.get("e.force:showToast");
            console.log("update")
            if (state === "SUCCESS") {
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "Migration process completed successfully.",
                    "type": "success"
                });
                toastEvent.fire();
            } else {
                toastEvent.setParams({
                    "title": "Error",
                    "message": "Migration process encountered an error.",
                    "type": "error"
                });
                toastEvent.fire();
            }
        });

        $A.enqueueAction(action);
    }
})