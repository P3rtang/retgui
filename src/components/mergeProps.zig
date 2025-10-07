const std = @import("std");

fn MergedStruct(comptime A: type, comptime B: type) type {
    // Create dummy values of each type to pass to mergeStructs
    const a_dummy: A = undefined;
    const b_dummy: B = undefined;
    return mergeStructs(a_dummy, b_dummy);
}

fn mergeStructs(a: anytype, b: anytype) type {
    const A = @TypeOf(a);
    const B = @TypeOf(b);

    const a_info = @typeInfo(A);
    const b_info = @typeInfo(B);

    if (a_info != .@"struct" or b_info != .@"struct") {
        @compileError("Both arguments must be structs");
    }

    const a_fields = a_info.@"struct".fields;
    const b_fields = b_info.@"struct".fields;

    // Calculate total number of unique fields
    var total_fields = a_fields.len;
    for (b_fields) |b_field| {
        var is_duplicate = false;
        for (a_fields) |a_field| {
            if (std.mem.eql(u8, a_field.name, b_field.name)) {
                is_duplicate = true;
                break;
            }
        }
        if (!is_duplicate) {
            total_fields += 1;
        }
    }

    // Create array to hold all unique fields
    var fields: [total_fields]std.builtin.Type.StructField = undefined;

    // Copy fields from first struct
    for (a_fields, 0..) |field, i| {
        fields[i] = field;
    }

    // Copy fields from second struct, checking for duplicates
    var unique_count: usize = a_fields.len;
    for (b_fields) |b_field| {
        var is_duplicate = false;
        for (a_fields) |a_field| {
            if (std.mem.eql(u8, a_field.name, b_field.name)) {
                is_duplicate = true;
                break;
            }
        }
        if (!is_duplicate) {
            fields[unique_count] = b_field;
            unique_count += 1;
        }
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

pub fn merge(a: anytype, b: anytype) MergedStruct(@TypeOf(a), @TypeOf(b)) {
    const MergedType = MergedStruct(@TypeOf(a), @TypeOf(b));
    const A = @TypeOf(a);
    const B = @TypeOf(b);

    const a_info = @typeInfo(A);
    const b_info = @typeInfo(B);

    if (a_info != .@"struct" or b_info != .@"struct") {
        @compileError("Both arguments must be structs");
    }

    var result: MergedType = undefined;

    // Copy all fields from first struct (these take precedence)
    inline for (a_info.@"struct".fields) |field| {
        @field(result, field.name) = @field(a, field.name);
    }

    // Copy fields from second struct only if they don't exist in first
    inline for (b_info.@"struct".fields) |b_field| {
        var field_exists_in_a = false;
        inline for (a_info.@"struct".fields) |a_field| {
            if (std.mem.eql(u8, a_field.name, b_field.name)) {
                field_exists_in_a = true;
                break;
            }
        }
        if (!field_exists_in_a) {
            @field(result, b_field.name) = @field(b, b_field.name);
        }
    }

    return result;
}
