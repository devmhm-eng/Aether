"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from "@/components/ui/dialog"
import {
    AlertDialog,
    AlertDialogAction,
    AlertDialogCancel,
    AlertDialogContent,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogHeader,
    AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Plus, Server, Pencil, Trash2 } from "lucide-react"

export default function NodesPage() {
    const [nodes, setNodes] = useState([])
    const [addDialogOpen, setAddDialogOpen] = useState(false)
    const [editDialogOpen, setEditDialogOpen] = useState(false)
    const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
    const [selectedNode, setSelectedNode] = useState<any>(null)
    const [formData, setFormData] = useState({ name: "", ip: "", key: "" })

    const fetchNodes = () => {
        fetch('/api/nodes')
            .then(res => res.json())
            .then(data => setNodes(data || []))
            .catch(err => console.error('Failed to load nodes:', err))
    }

    useEffect(() => {
        fetchNodes()
    }, [])

    const handleAddNode = async () => {
        await fetch('/api/nodes', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(formData)
        })
        setAddDialogOpen(false)
        setFormData({ name: "", ip: "", key: "" })
        fetchNodes()
    }

    const handleEditNode = async () => {
        await fetch('/api/nodes', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                id: selectedNode.id,
                name: formData.name,
                ip: formData.ip
            })
        })
        setEditDialogOpen(false)
        fetchNodes()
    }

    const handleDeleteNode = async () => {
        await fetch(`/api/nodes?id=${selectedNode.id}`, { method: 'DELETE' })
        setDeleteDialogOpen(false)
        fetchNodes()
    }

    return (
        <div className="flex-1 space-y-4 p-8 pt-6">
            <div className="flex items-center justify-between">
                <h2 className="text-3xl font-bold tracking-tight">Server Nodes</h2>

                <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
                    <DialogTrigger asChild>
                        <Button>
                            <Plus className="mr-2 h-4 w-4" /> Add Node
                        </Button>
                    </DialogTrigger>
                    <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                        <DialogHeader>
                            <DialogTitle>Add New Node</DialogTitle>
                            <DialogDescription className="text-zinc-400">
                                Connect a new Aether server to the network.
                            </DialogDescription>
                        </DialogHeader>
                        <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                                <Label htmlFor="node-name">Node Name</Label>
                                <Input
                                    id="node-name"
                                    className="bg-zinc-800 border-zinc-700"
                                    value={formData.name}
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                    placeholder="US-NewYork-01"
                                />
                            </div>
                            <div className="grid gap-2">
                                <Label htmlFor="node-ip">IP Address</Label>
                                <Input
                                    id="node-ip"
                                    className="bg-zinc-800 border-zinc-700"
                                    value={formData.ip}
                                    onChange={(e) => setFormData({ ...formData, ip: e.target.value })}
                                    placeholder="192.168.1.100"
                                />
                            </div>
                            <div className="grid gap-2">
                                <Label htmlFor="node-key">Admin Key</Label>
                                <Input
                                    id="node-key"
                                    type="password"
                                    className="bg-zinc-800 border-zinc-700"
                                    value={formData.key}
                                    onChange={(e) => setFormData({ ...formData, key: e.target.value })}
                                    placeholder="HORIZON_MASTER_KEY"
                                />
                            </div>
                        </div>
                        <DialogFooter>
                            <Button onClick={handleAddNode}>Add Node</Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
            </div>

            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                {nodes.map((node: any) => (
                    <Card key={node.id} className="bg-zinc-900 border-zinc-800 text-white relative">
                        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                            <CardTitle className="text-sm font-medium">
                                <div className="flex items-center gap-2">
                                    <Server className="h-4 w-4 text-emerald-500" />
                                    {node.name || 'Unknown Node'}
                                </div>
                            </CardTitle>
                            <div className="flex gap-1">
                                <Button
                                    variant="ghost"
                                    size="icon"
                                    className="h-7 w-7"
                                    onClick={() => {
                                        setSelectedNode(node)
                                        setFormData({ name: node.name, ip: node.ip, key: "" })
                                        setEditDialogOpen(true)
                                    }}
                                >
                                    <Pencil className="h-3 w-3" />
                                </Button>
                                <Button
                                    variant="ghost"
                                    size="icon"
                                    className="h-7 w-7"
                                    onClick={() => {
                                        setSelectedNode(node)
                                        setDeleteDialogOpen(true)
                                    }}
                                >
                                    <Trash2 className="h-3 w-3 text-red-500" />
                                </Button>
                            </div>
                        </CardHeader>
                        <CardContent className="space-y-3">
                            <div className="flex items-center justify-between">
                                <span className="text-xs text-zinc-400 font-mono">{node.ip}</span>
                                <Badge
                                    variant={node.status === 'active' ? 'default' : 'destructive'}
                                    className={node.status === 'active' ? 'bg-emerald-600' : 'bg-red-600'}
                                >
                                    {node.status || 'offline'}
                                </Badge>
                            </div>
                        </CardContent>
                    </Card>
                ))}

                {nodes.length === 0 && (
                    <div className="col-span-3 text-center text-zinc-500 py-8">
                        No nodes configured. Click "Add Node" to get started.
                    </div>
                )}
            </div>

            {/* Edit Dialog */}
            <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                    <DialogHeader>
                        <DialogTitle>Edit Node</DialogTitle>
                        <DialogDescription className="text-zinc-400">
                            Update node details.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                        <div className="grid gap-2">
                            <Label htmlFor="edit-node-name">Node Name</Label>
                            <Input
                                id="edit-node-name"
                                className="bg-zinc-800 border-zinc-700"
                                value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                            />
                        </div>
                        <div className="grid gap-2">
                            <Label htmlFor="edit-node-ip">IP Address</Label>
                            <Input
                                id="edit-node-ip"
                                className="bg-zinc-800 border-zinc-700"
                                value={formData.ip}
                                onChange={(e) => setFormData({ ...formData, ip: e.target.value })}
                            />
                        </div>
                    </div>
                    <DialogFooter>
                        <Button onClick={handleEditNode}>Save Changes</Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            {/* Delete Confirmation */}
            <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
                <AlertDialogContent className="bg-zinc-900 border-zinc-800 text-white">
                    <AlertDialogHeader>
                        <AlertDialogTitle>Remove Node?</AlertDialogTitle>
                        <AlertDialogDescription className="text-zinc-400">
                            This will disconnect <strong>{selectedNode?.name}</strong> from the Horizon network.
                            Users on this node will no longer be managed.
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogCancel className="bg-zinc-800 border-zinc-700">Cancel</AlertDialogCancel>
                        <AlertDialogAction onClick={handleDeleteNode} className="bg-red-600 hover:bg-red-700">
                            Remove
                        </AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>
        </div>
    )
}
