import { DynamoDBClient, GetItemCommand, QueryCommand } from "@aws-sdk/client-dynamodb";

const dynamo = new DynamoDBClient({});
const tableName = process.env.TABLE_NAME;

function unmarshalValue(value) {
  if ("S" in value) return value.S;
  if ("N" in value) return Number(value.N);
  if ("BOOL" in value) return value.BOOL;
  if ("NULL" in value) return null;
  if ("B" in value) return Buffer.from(value.B).toString("base64");
  if ("SS" in value) return value.SS;
  if ("NS" in value) return value.NS.map(Number);
  if ("BS" in value) return value.BS.map((entry) => Buffer.from(entry).toString("base64"));
  if ("L" in value) return value.L.map(unmarshalValue);
  if ("M" in value) return unmarshalItem(value.M);
  return undefined;
}

function unmarshalItem(item) {
  return Object.fromEntries(
    Object.entries(item).map(([key, value]) => [key, unmarshalValue(value)]),
  );
}

function serializeItem(item) {
  const { pk, sk, ...attributes } = unmarshalItem(item);
  return { id: sk, ...attributes };
}

const json = (statusCode, body) => ({
  statusCode,
  headers: {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  },
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  if (!tableName) {
    console.error("TABLE_NAME is not configured");
    return json(500, { message: "Service is not configured" });
  }

  const method = event.requestContext?.http?.method ?? event.httpMethod;
  const itemId = event.pathParameters?.itemId;

  if (method !== "GET") {
    return json(405, { message: "Method not allowed" });
  }

  try {
    if (itemId) {
      const result = await dynamo.send(
        new GetItemCommand({
          TableName: tableName,
          Key: { pk: { S: "ITEM" }, sk: { S: itemId } },
        }),
      );

      return result.Item
        ? json(200, serializeItem(result.Item))
        : json(404, { message: "Item not found" });
    }

    const result = await dynamo.send(
      new QueryCommand({
        TableName: tableName,
        KeyConditionExpression: "#pk = :pk",
        ExpressionAttributeNames: { "#pk": "pk" },
        ExpressionAttributeValues: { ":pk": { S: "ITEM" } },
        ScanIndexForward: true,
      }),
    );

    return json(200, { items: (result.Items ?? []).map(serializeItem) });
  } catch (error) {
    console.error("DynamoDB request failed", error);
    return json(500, { message: "Unable to read items" });
  }
};
