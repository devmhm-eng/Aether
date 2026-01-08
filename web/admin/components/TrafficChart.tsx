"use client"

import { Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

const data = [
    { time: "00:00", traffic: 240 },
    { time: "04:00", traffic: 139 },
    { time: "08:00", traffic: 980 },
    { time: "12:00", traffic: 390 },
    { time: "16:00", traffic: 480 },
    { time: "20:00", traffic: 380 },
    { time: "23:59", traffic: 430 },
]

export function TrafficChart() {
    return (
        <Card className="col-span-4 bg-zinc-900 border-zinc-800 text-white">
            <CardHeader>
                <CardTitle>Network Traffic (24h)</CardTitle>
            </CardHeader>
            <CardContent className="pl-2">
                <div className="h-[200px]">
                    <ResponsiveContainer width="100%" height="100%">
                        <LineChart data={data}>
                            <XAxis dataKey="time" stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                            <YAxis stroke="#888888" fontSize={12} tickLine={false} axisLine={false} tickFormatter={(value) => `${value}MB`} />
                            <Tooltip
                                contentStyle={{ backgroundColor: "#18181b", border: "1px solid #27272a" }}
                                labelStyle={{ color: "#a1a1aa" }}
                            />
                            <Line type="monotone" dataKey="traffic" stroke="#10b981" strokeWidth={2} dot={false} />
                        </LineChart>
                    </ResponsiveContainer>
                </div>
            </CardContent>
        </Card>
    )
}
