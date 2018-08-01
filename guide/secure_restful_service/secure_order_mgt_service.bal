import ballerina/http;

//@docker:Config {
//    registry:"ballerina.guides.io",
//    name:"secure_restful_service",
//    tag:"v1.0"
//}
//
//@docker:Expose{}

//@kubernetes:Ingress {
//    hostname:"ballerina.guides.io",
//    name:"ballerina-guides-secure-restful-service",
//    path:"/"
//}
//
//@kubernetes:Service {
//    serviceType:"NodePort",
//    name:"ballerina-guides-secure-restful-service"
//}
//
//@kubernetes:Deployment {
//    image:"ballerina.guides.io/secure_restful_service:v1.0",
//    name:"ballerina-guides-secure-restful-service"
//}

@final string regexInt = "\\d+";
@final string regexJson = "[a-zA-Z0-9.,{}:\" ]*";

http:AuthProvider basicAuthProvider = {
    scheme: "basic",
    authStoreProvider: "config"
};
endpoint http:SecureListener listener {
    port: 9090,
    authProviders: [basicAuthProvider]
};

// Order management is done using an in memory map.
// Add some sample orders to 'orderMap' at startup.
map<json> ordersMap;

@Description { value: "RESTful service." }
@http:ServiceConfig {
    basePath: "/ordermgt",
    authConfig: {
        authentication: { enabled: true }
    }
}
service<http:Service> order_mgt bind listener {

    @Description { value: "Resource that handles the HTTP POST requests that are directed
     to the path '/orders' to create a new Order." }
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/order",
        authConfig: {
            scopes: ["add_order"]
        }
    }
    addOrder(endpoint client, http:Request req) {
        json orderReq = check req.getJsonPayload();
        string orderId = orderReq.Order.ID.toString();

        // Get untainted value if `orderId` is a valid input
        orderId = getUntaintedStringIfValid(orderId);

        ordersMap[orderId] = orderReq;

        // Create response message.
        json payload = { status: "Order Created.", orderId: orderId };
        http:Response response;
        response.setJsonPayload(payload);

        // Set 201 Created status code in the response message.
        response.statusCode = 201;
        // Set 'Location' header in the response message.
        // This can be used by the client to locate the newly added order.
        response.setHeader("Location", "http://localhost:9090/ordermgt/order/" + orderId);

        // Send response to the client.
        _ = client->respond(response);
    }

    @Description { value: "Resource that handles the HTTP PUT requests that are directed
    to the path '/orders' to update an existing Order." }
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/order/{orderId}",
        authConfig: {
            scopes: ["update_order"]
        }
    }
    updateOrder(endpoint client, http:Request req, string orderId) {
        json updatedOrder = check req.getJsonPayload();

        // Get untainted value if `orderId` is a valid input
        orderId = getUntaintedStringIfValid(orderId);

        // Find the order that needs to be updated and retrieve it in JSON format.
        json existingOrder = ordersMap[orderId];

        // Get untainted json value if it is a valid json
        existingOrder = getUntaintedJsonIfValid(existingOrder);
        updatedOrder = getUntaintedJsonIfValid(updatedOrder);

        // Updating existing order with the attributes of the updated order.
        if (existingOrder != null) {

            existingOrder.Order.Name = updatedOrder.Order.Name;
            existingOrder.Order.Description = updatedOrder.Order.Description;
            ordersMap[orderId] = existingOrder;
        } else {
            existingOrder = "Order : " + orderId + " cannot be found.";
        }

        http:Response response;
        // Set the JSON payload to the outgoing response message to the client.
        response.setJsonPayload(existingOrder);
        // Send response to the client.
        _ = client->respond(response);
    }

    @Description { value: "Resource that handles the HTTP DELETE requests, which are
    directed to the path '/orders/<orderId>' to delete an existing Order." }
    @http:ResourceConfig {
        methods: ["DELETE"],
        path: "/order/{orderId}",
        authConfig: {
            scopes: ["cancel_order"]
        }
    }
    cancelOrder(endpoint client, http:Request req, string orderId) {
        // Get untainted string value if `orderId` is a valid input
        orderId = getUntaintedStringIfValid(orderId);

        // Remove the requested order from the map.
        _ = ordersMap.remove(orderId);

        http:Response response;
        json payload = "Order : " + orderId + " removed.";
        // Set a generated payload with order status.
        response.setJsonPayload(payload);

        // Send response to the client.
        _ = client->respond(response);
    }

    @Description { value: "Resource that handles the HTTP GET requests that are directed
    to a specific order using path '/orders/<orderID>'" }
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/order/{orderId}",
        authConfig: {
            authentication: { enabled: false }
        }
    }
    findOrder(endpoint client, http:Request req, string orderId) {
        // Get untainted string value if `orderId` is a valid input
        orderId = getUntaintedStringIfValid(orderId);

        // Find the requested order from the map and retrieve it in JSON format.
        http:Response response;
        json payload;
        if (ordersMap.hasKey(orderId)) {
            payload = ordersMap[orderId];
        } else {
            response.statusCode = 404;
            payload = "Order : " + orderId + " cannot be found.";
        }

        // Set the JSON payload in the outgoing response message.
        response.setJsonPayload(payload);

        // Send response to the client.
        _ = client->respond(response);
    }
}

function getUntaintedStringIfValid(string input) returns @untainted string {
    boolean isValid = check input.matches(regexInt);
    if (isValid) {
        return input;
    } else {
        error err = { message: "Validation error: Input '" + input + "' should be valid." };
        throw err;
    }
}

function getUntaintedJsonIfValid(json input) returns @untainted json {
    string inputStr = input.toString();
    boolean isValid = check inputStr.matches(regexJson);
    if (isValid) {
        return input;
    } else {
        error err = { message: "Validation error: Input payload '" + inputStr + "' should be valid." };
        throw err;
    }
}
