"use client"

import { useState, useEffect } from "react"
import { Card } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Trash2, Smartphone } from "lucide-react"

export default function DevicesPage() {
    const [devices, setDevices] = useState<any[]>([])

    const fetchDevices = async () => {
        const res = await fetch('/api/devices', { cache: 'no-store' })
        const data = await res.json()
        setDevices(data || [])
    }

    useEffect(() => {
        fetchDevices()
        const interval = setInterval(fetchDevices, 5000)
        return () => clearInterval(interval)
    }, [])

    const deleteDevice = async (id: number) => {
        await fetch(`/api/devices?id=${id}`, { method: 'DELETE' })
        fetchDevices()
    }

    return (
        <div className="p-6">
            <div className="flex justify-between items-center mb-6">
                <h1 className="text-2xl font-bold">Registered Devices</h1>
                <Badge variant="outline">{devices.length} devices</Badge>
            </div>

            <div className="grid gap-4">
                {devices.length === 0 ? (
                    <Card className="p-8 text-center text-muted-foreground">
                        <Smartphone className="w-12 h-12 mx-auto mb-4 opacity-50" />
                        <p>No devices registered yet</p>
                        <p className="text-sm mt-2">Devices will appear here when users connect via the app</p>
                    </Card>
                ) : (
                    devices.map((device) => (
                        <Card key={device.id} className="p-4">
                            <div className="flex items-center justify-between">
                                <div className="flex-1">
                                    <div className="flex items-center gap-3 mb-2">
                                        <Smartphone className="w-5 h-5" />
                                        <span className="font-semibold">{device.label || 'Unknown Device'}</span>
                                        <Badge variant={device.status === 'active' ? 'default' : 'secondary'}>
                                            {device.status}
                                        </Badge>
                                    </div>
                                    <div className="text-sm text-muted-foreground space-y-1">
                                        <div><span className="font-medium">Hardware ID:</span> {device.hardware_id}</div>
                                        {device.user_name && (
                                            <div><span className="font-medium">User:</span> {device.user_name} ({device.user_uuid})</div>
                                        )}
                                        <div><span className="font-medium">Last Seen:</span> {device.last_seen}</div>
                                    </div>
                                </div>
                                <Button
                                    variant="destructive"
                                    size="icon"
                                    onClick={() => deleteDevice(device.id)}
                                >
                                    <Trash2 className="w-4 h-4" />
                                </Button>
                            </div>
                        </Card>
                    ))
                )}
            </div>
        </div>
    )
}
